import Foundation
import IOKit

/// AppleSMC user client — direct port of the SMCKeyData_t struct + call
/// sequence used by smcFanControl / Stats. layout (84 bytes):
/// 0 key · 4 vers · 12 pLimit · 28 keyInfo.dataSize · 32 keyInfo.dataType ·
/// 40 pad · 42 result · 43 status · 44 data8(command) · 48 data32 · 52 bytes[32]
public final class SMCClient {

    public enum SMCError: Error, CustomStringConvertible {
        case notOpen
        case badKey
        case iokit(kern_return_t)
        case smcStatus(UInt8)

        public var description: String {
            switch self {
            case .notOpen: return "SMC connection not open"
            case .badKey: return "bad key (need exactly 4 chars)"
            case .iokit(let kr): return "IOKit error 0x\(String(UInt32(bitPattern: kr), radix: 16))"
            case .smcStatus(let s): return "SMC rejected (status 0x\(String(s, radix: 16)))"
            }
        }
    }

    public struct Value {
        public let key: String
        public let type: String
        public let bytes: [UInt8]
    }

    private enum Command {
        static let readBytes: UInt8 = 5
        static let writeBytes: UInt8 = 6
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

    public init() throws {
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

    deinit {
        if conn != 0 { IOServiceClose(conn) }
    }

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

    public func readKey(_ key: String) throws -> Value {
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

    /// writes require the process to run as root
    public func writeKey(_ key: String, bytes: [UInt8]) throws {
        guard key.count == 4, (1...32).contains(bytes.count) else { throw SMCError.badKey }
        var input = SMCKeyData()
        var output = SMCKeyData()

        input.key = Self.fourCC(key)
        input.keyInfo.dataSize = IOByteCount32(bytes.count)
        input.data8 = Command.writeBytes
        withUnsafeMutableBytes(of: &input.bytes) { raw in
            raw.copyBytes(from: bytes)
        }
        try call(&input, &output)
    }
    
    /// every key name in the firmware, via READ_INDEX
    public func allKeys() -> [String] {
        var out: [String] = []
        var index: UInt32 = 0
        while true {
            var input = SMCKeyData()
            var output = SMCKeyData()
            input.key = Self.fourCC("#KEY")
            input.data8 = 8          // READ_INDEX
            input.data32 = index
            do {
                try call(&input, &output)
            } catch {
                break   // out of range = done
            }
            let all = withUnsafeBytes(of: output.bytes) { Array($0) }
            let name = String(bytes: all.prefix(4), encoding: .ascii) ?? ""
            if name.trimmingCharacters(in: .whitespaces).isEmpty { break }
            out.append(name)
            index += 1
        }
        return out
    }

    public func doubleValue(_ v: Value) -> Double? {
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
        return String(bytes: b, encoding: .ascii) ?? "????"
    }
}

/// static facade so app + daemon can share one lazy client
public enum SMC {
    nonisolated(unsafe) private static var _client: SMCClient?
    private static let _lock = NSLock()

    static func client() -> SMCClient? {
        _lock.lock()
        defer { _lock.unlock() }
        if _client == nil { _client = try? SMCClient() }
        return _client
    }

    public static var shared: SMCClient? { client() }
    
    public static func temperatureC(_ key: String) -> Double? {
        guard let c = client(), let v = try? c.readKey(key) else { return nil }
        return c.doubleValue(v)
    }

    public static func batteryTemperatureC() -> Double? {
        for key in ["TB1T", "TB2T", "TB0T"] {
            if let t = temperatureC(key) { return t }
        }
        return nil
    }

    public static func probe(_ key: String) -> String {
        guard let c = client() else { return "no AppleSMC connection" }
        do {
            let v = try c.readKey(key)
            let hex = v.bytes.map { String(format: "%02x", $0) }.joined(separator: " ")
            var s = "type=\(v.type) data[\(v.bytes.count)]=\(hex)"
            if let d = c.doubleValue(v) { s += " -> \(d)" }
            return s
        } catch {
            if case SMCClient.SMCError.smcStatus(let st) = error {
                return "SMC rejected (status 0x\(String(st, radix: 16))) — key missing?"
            }
            return "error: \(error)"
        }
    }
}
