import Foundation
import IOKit

final class SMCClient {
    enum SMCError: Error {
        case notOpen, badKey, iokit(kern_return_t), smcStatus(UInt8)
    }
    struct Value {
        let key: String
        let type: String
        let bytes: [UInt8]
    }
    private enum Command {
        static let readBytes: UInt8 = 5
        static let readKeyInfo: UInt8 = 9
    }
    private static let kernelIndex: UInt32 = 2

    private typealias Bytes32 = (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                                 UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                                 UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                                 UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)
    private struct KeyInfoData {
        var dataSize: IOByteCount32 = 0
        var dataType: UInt32 = 0
        var dataAttributes: UInt8 = 0
    }
    private struct SMCKeyData {
        var key: UInt32 = 0
        var versMajor: UInt8 = 0
        var versMinor: UInt8 = 0
        var versBuild: UInt8 = 0
        var versReserved: UInt8 = 0
        var versRelease: UInt16 = 0
        var pLimitVersion: UInt16 = 0
        var pLimitLength: UInt16 = 0
        var cpuPLimit: UInt32 = 0
        var gpuPLimit: UInt32 = 0
        var memPLimit: UInt32 = 0
        var keyInfo = KeyInfoData()
        var padding: UInt16 = 0
        var result: UInt8 = 0
        var status: UInt8 = 0
        var data8: UInt8 = 0
        var data32: UInt32 = 0
        var bytes: Bytes32 = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
    }

    private var conn: io_connect_t = 0
    private let lock = NSLock()

    init() throws {
        var iterator: io_iterator_t = 0
        let kr = IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("AppleSMC"), &iterator)
        guard kr == KERN_SUCCESS else { throw SMCError.iokit(kr) }
        defer { IOObjectRelease(iterator) }
        let device = IOIteratorNext(iterator)
        guard device != IO_OBJECT_NULL else { throw SMCError.notOpen }
        var c: io_connect_t = 0
        let krOpen = IOServiceOpen(device, mach_task_self_, 0, &c)
        IOObjectRelease(device)
        guard krOpen == KERN_SUCCESS else { throw SMCError.iokit(krOpen) }
        conn = c
    }
    deinit { if conn != 0 { IOServiceClose(conn) } }

    private func call(_ input: inout SMCKeyData, _ output: inout SMCKeyData) throws {
        lock.lock()
        defer { lock.unlock() }
        let size = MemoryLayout<SMCKeyData>.stride
        var outputSize = size
        let kr: kern_return_t = withUnsafeBytes(of: input) { inRaw in
            withUnsafeMutableBytes(of: &output) { outRaw in
                IOConnectCallStructMethod(
                    conn, Self.kernelIndex,
                    inRaw.bindMemory(to: UInt8.self).baseAddress, size,
                    outRaw.bindMemory(to: UInt8.self).baseAddress, &outputSize
                )
            }
        }
        guard kr == KERN_SUCCESS else { throw SMCError.iokit(kr) }
        guard output.result == 0 else { throw SMCError.smcStatus(output.result) }
    }

    func readKey(_ key: String) throws -> Value {
        guard key.count == 4 else { throw SMCError.badKey }
        var input = SMCKeyData()
        var output = SMCKeyData()
        input.key = Self.fourCC(key)
        input.data8 = Command.readKeyInfo
        try call(&input, &output)
        let dataSize = Int(output.keyInfo.dataSize)
        let type = Self.typeString(output.keyInfo.dataType)
        guard (1...32).contains(dataSize) else { throw SMCError.smcStatus(output.status) }
        input.keyInfo.dataSize = output.keyInfo.dataSize
        input.data8 = Command.readBytes
        try call(&input, &output)
        let all = withUnsafeBytes(of: output.bytes) { Array($0) }
        return Value(key: key, type: type, bytes: Array(all.prefix(dataSize)))
    }

    func doubleValue(_ v: Value) -> Double? {
        let b = v.bytes
        switch v.type {
        case "ui8 ", "flag": return b.isEmpty ? nil : Double(b[0])
        case "ui16": return b.count >= 2 ? Double(UInt16(b[0]) << 8 | UInt16(b[1])) : nil
        case "ui32": return b.count >= 4 ? Double(UInt32(b[0]) << 24 | UInt32(b[1]) << 16 | UInt32(b[2]) << 8 | UInt32(b[3])) : nil
        case "sp78": return b.count >= 2 ? Double(Int8(bitPattern: b[0])) + Double(b[1]) / 256 : nil
        case "flt ":
            guard b.count >= 4 else { return nil }
            let u = UInt32(b[0]) | UInt32(b[1]) << 8 | UInt32(b[2]) << 16 | UInt32(b[3]) << 24
            let f = Float(bitPattern: u)
            return f.isFinite ? Double(f) : nil
        default: return nil
        }
    }

    private static func fourCC(_ s: String) -> UInt32 {
        s.utf8.reduce(0) { $0 << 8 | UInt32($1) }
    }
    private static func typeString(_ v: UInt32) -> String {
        let b = [UInt8((v >> 24) & 0xFF), UInt8((v >> 16) & 0xFF), UInt8((v >> 8) & 0xFF), UInt8(v & 0xFF)]
        return String(bytes: b, encoding: .ascii) ?? ""
    }
}

func batteryBasics() -> (percent: Int, charging: Bool, plugged: Bool) {
    let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
    guard service != IO_OBJECT_NULL else { return (0, false, false) }
    var out = (0, false, false)
    var props: Unmanaged<CFMutableDictionary>?
    if IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == kIOReturnSuccess,
       let cf = props?.takeRetainedValue(),
       let d = (cf as NSDictionary) as? [String: Any] {
        out.0 = (d["CurrentCapacity"] as? NSNumber)?.intValue ?? 0
        out.1 = (d["IsCharging"] as? NSNumber)?.intValue == 1
        out.2 = (d["ExternalConnected"] as? NSNumber)?.intValue == 1
    }
    IOObjectRelease(service)
    return out
}

let label = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "run"

guard let client = try? SMCClient() else { print("no SMC connection"); exit(1) }

let b = batteryBasics()
var lines: [String] = []
lines.append("state=\(label) percent=\(b.percent) charging=\(b.charging) plugged=\(b.plugged)")

let candidates = ["ACLC","ACLM","B0CH","BCHT","CBCL","CH0D","CH0E","CH0H","CH0J","CH0R","CH0V",
                  "CHA1","CHA2","CHAI","CHAS","CHBI","CHBV","CHCC","CHCE","CHCF","CHCR","CHDB",
                  "CHFS","CHHC","CHHV","CHHW","CHI1","CHI2","CHIB","CHIC","CHIE","CHIF","CHIL",
                  "CHIM","CHIO","CHIS","CHLS","CHLT","CHM2","CHNC","CHND","CHOC","CHPS","CHRT",
                  "CHSC","CHSE","CHSL","CHST","CHSW","CHTC","PBAT","PSTR","TCHP","UBAT","bcl0","fchx"]

for k in candidates {
    do {
        let v = try client.readKey(k)
        let hex = v.bytes.map { String(format: "%02x", $0) }.joined(separator: " ")
        let dec = client.doubleValue(v).map { String(format: "%.3f", $0) } ?? "-"
        lines.append("\(k)  \(v.type)  [\(hex)]  \(dec)")
    } catch {
        lines.append("\(k)  ERROR \(error)")
    }
}

let out = lines.joined(separator: "\n")
print(out)
let path = "/tmp/glide-probe-\(label).txt"
try! out.write(toFile: path, atomically: true, encoding: .utf8)
print("\nwrote \(path)")