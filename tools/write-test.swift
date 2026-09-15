import Foundation
import IOKit

final class SMCClient {
    enum SMCError: Error { case notOpen, badKey, iokit(kern_return_t), smcStatus(UInt8) }
    private enum Command {
        static let writeBytes: UInt8 = 6
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
        let size = MemoryLayout<SMCKeyData>.stride
        var outputSize = size
        let kr: kern_return_t = withUnsafeBytes(of: input) { inRaw in
            withUnsafeMutableBytes(of: &output) { outRaw in
                IOConnectCallStructMethod(conn, Self.kernelIndex,
                    inRaw.bindMemory(to: UInt8.self).baseAddress, size,
                    outRaw.bindMemory(to: UInt8.self).baseAddress, &outputSize)
            }
        }
        guard kr == KERN_SUCCESS else { throw SMCError.iokit(kr) }
        guard output.result == 0 else { throw SMCError.smcStatus(output.result) }
    }
    func readKey(_ key: String) throws -> (type: UInt32, bytes: [UInt8]) {
        guard key.count == 4 else { throw SMCError.badKey }
        var input = SMCKeyData()
        var output = SMCKeyData()
        input.key = Self.fourCC(key)
        input.data8 = Command.readKeyInfo
        try call(&input, &output)
        let dataSize = Int(output.keyInfo.dataSize)
        guard (1...32).contains(dataSize) else { throw SMCError.smcStatus(output.status) }
        input.keyInfo.dataSize = output.keyInfo.dataSize
        input.data8 = Command.readBytes
        try call(&input, &output)
        let all = withUnsafeBytes(of: output.bytes) { Array($0) }
        return (output.keyInfo.dataType, Array(all.prefix(dataSize)))
    }
    func writeKey(_ key: String, bytes: [UInt8]) throws {
        guard key.count == 4, (1...32).contains(bytes.count) else { throw SMCError.badKey }
        var input = SMCKeyData()
        var output = SMCKeyData()
        input.key = Self.fourCC(key)
        input.keyInfo.dataSize = IOByteCount32(bytes.count)
        input.data8 = Command.writeBytes
        withUnsafeMutableBytes(of: &input.bytes) { raw in raw.copyBytes(from: bytes) }
        try call(&input, &output)
    }
    private static func fourCC(_ s: String) -> UInt32 { s.utf8.reduce(0) { $0 << 8 | UInt32($1) } }
}

guard geteuid() == 0 else { print("must run with sudo"); exit(1) }
guard let client = try? SMCClient() else { print("no SMC connection"); exit(1) }

let key = "CHLT"
print("reading \(key)...")
let current = try! client.readKey(key)
print("current: \(current.bytes.map { String(format: "%02x", $0) }.joined(separator: " "))")

var newBytes = current.bytes
if current.bytes[0] == 0x50 {
    newBytes[0] = 0x5a // 90%
    print("writing 90% (5a)...")
} else {
    newBytes[0] = 0x50 // 80%
    print("writing 80% (50)...")
}

do {
    try client.writeKey(key, bytes: newBytes)
    print("write success!")
} catch {
    print("write failed: \(error)")
    exit(1)
}

print("reading \(key) again...")
let updated = try! client.readKey(key)
print("updated: \(updated.bytes.map { String(format: "%02x", $0) }.joined(separator: " "))")