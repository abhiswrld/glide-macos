import Foundation
import IOKit

final class SMCClient {
    enum SMCError: Error {
        case notOpen, badKey, iokit(kern_return_t), smcStatus(UInt8)
    }

    private enum Command {
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

    func allKeys() -> [String] {
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
                break
            }
            // THE FIX: name comes back in the `key` field, not in `bytes`
            let name = Self.typeString(output.key)
            if name.isEmpty { break }
            out.append(name)
            index += 1
        }
        return out
    }

    private static func fourCC(_ s: String) -> UInt32 {
        s.utf8.reduce(0) { $0 << 8 | UInt32($1) }
    }
    private static func typeString(_ v: UInt32) -> String {
        let b = [UInt8((v >> 24) & 0xFF), UInt8((v >> 16) & 0xFF), UInt8((v >> 8) & 0xFF), UInt8(v & 0xFF)]
        return String(bytes: b, encoding: .ascii) ?? ""
    }
}

print("running as \(geteuid() == 0 ? "root" : "regular user")")

guard let client = try? SMCClient() else {
    print("no SMC connection")
    exit(1)
}

let keys = client.allKeys()
print("SMC has \(keys.count) keys")

let text = keys.joined(separator: "\n")
try! text.write(toFile: "/tmp/glide-smc-keys.txt", atomically: true, encoding: .utf8)
print("wrote /tmp/glide-smc-keys.txt")

print("\n--- first 40 keys ---")
for k in keys.prefix(40) { print(k) }

let interesting = keys.filter { k in
    let k = k.uppercased()
    return k.contains("CH") || k.contains("BCL") || k.contains("BAT") ||
           k.contains("ACL") || k.contains("ACW") || k.contains("PSTR") ||
           k.contains("CHARGE") || k.contains("POWER")
}
print("\n--- candidate keys (\(interesting.count)) ---")
for k in interesting.sorted() { print(k) }