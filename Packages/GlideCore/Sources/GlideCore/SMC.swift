//
//  SMC.swift
//  GlideCore
//
//  Created by Abhinav on 9/14/26.
//

import Foundation
import IOKit

/// AppleSMC user-client client.
/// The kernel ABI (a ~84-96 byte struct whose field offsets vary by variant)
/// is discovered at runtime instead of hardcoded.
public enum SMC {

    public struct ABI: Sendable {
        let size: Int
        let dataSizeOffset: Int
        let dataTypeOffset: Int
        let cmdOffset: Int
        let bytesOffset: Int
    }

    private static let selector: UInt32 = 2

    nonisolated(unsafe) private static var conn: io_connect_t = 0
    nonisolated(unsafe) private static var cachedABI: ABI?
    nonisolated(unsafe) private static var discoveryFailed = false

    private static func connection() -> io_connect_t? {
        if conn != 0 { return conn }
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != IO_OBJECT_NULL else { return nil }
        defer { IOObjectRelease(service) }
        var c: io_connect_t = 0
        guard IOServiceOpen(service, mach_task_self_, 0, &c) == KERN_SUCCESS else { return nil }
        var openOut = 0
        guard IOConnectCallStructMethod(c, 0, nil, 0, nil, &openOut) == KERN_SUCCESS else {
            IOServiceClose(c)
            return nil
        }
        conn = c
        return conn
    }

    private static func call(_ buf: [UInt8]) -> (kr: kern_return_t, out: [UInt8]) {
        guard let c = connection() else { return (KERN_FAILURE, []) }
        var out = [UInt8](repeating: 0, count: buf.count)
        var outSize = buf.count
        let kr: kern_return_t = buf.withUnsafeBytes { inRaw in
            out.withUnsafeMutableBytes { outRaw in
                IOConnectCallStructMethod(
                    c, selector,
                    inRaw.bindMemory(to: UInt8.self).baseAddress, buf.count,
                    outRaw.bindMemory(to: UInt8.self).baseAddress, &outSize
                )
            }
        }
        return (kr, out)
    }

    /// try (structSize, cmdOffset) combos against "#KEY" until one returns a
    /// valid keyinfo response, then confirm with a real value read.
    public static func discoverABI(verbose: Bool = false) -> ABI? {
        if let cachedABI { return cachedABI }
        if discoveryFailed && !verbose { return nil }
        guard connection() != nil else { return nil }

        let sizes = [88, 84, 96, 92, 80, 64]
        let cmds = [51, 47, 55, 43, 59, 39]

        for size in sizes {
            for cmd in cmds where cmd + 12 < size {
                var buf = [UInt8](repeating: 0, count: size)
                pack("#KEY", into: &buf)
                buf[cmd] = 9              // SMC_CMD_READ_KEYINFO
                let r = call(buf)
                if verbose {
                    print("probe size=\(size) cmd=\(cmd) kr=0x\(String(UInt32(bitPattern: r.kr), radix: 16))")
                }
                guard r.kr == KERN_SUCCESS else { continue }

                // response signature: dataSize(1-32) at X-4, 4 printable ASCII
                // type chars at X, result byte == 0 a few bytes later
                for typeOff in 24..<min(64, size - 8) {
                    let ds = Int(le32(r.out, at: typeOff - 4))
                    let sig = r.out[typeOff..<typeOff + 4]
                    let resultByte = typeOff + 5 < size ? r.out[typeOff + 5] : 0xFF
                    guard (1...32).contains(ds),
                          sig.allSatisfy({ (0x20...0x7E).contains($0) }),
                          resultByte == 0
                    else { continue }

                    let data8 = typeOff + 7
                    guard data8 == cmd else { continue }
                    let bytesOff = align4(data8 + 1) + 4
                    guard bytesOff + 32 <= size else { continue }

                    let abi = ABI(size: size, dataSizeOffset: typeOff - 4,
                                  dataTypeOffset: typeOff, cmdOffset: data8,
                                  bytesOffset: bytesOff)

                    // end-to-end check: #KEY holds the number of SMC keys
                    if let v = readUInt32("#KEY", abi: abi), (50...20000).contains(v) {
                        if verbose { print("ABI found: size=\(size) cmd=\(cmd) typeOff=\(typeOff) #KEY=\(v)") }
                        cachedABI = abi
                        return abi
                    }
                }
            }
        }
        discoveryFailed = true
        return nil
    }

    private static func readRaw(_ key: String, abi: ABI) -> (type: String, data: [UInt8])? {
        guard key.count == 4 else { return nil }

        var buf = [UInt8](repeating: 0, count: abi.size)
        pack(key, into: &buf)
        buf[abi.cmdOffset] = 9
        let r1 = call(buf)
        guard r1.kr == KERN_SUCCESS, r1.out[abi.cmdOffset - 2] == 0 else { return nil }
        let ds = Int(le32(r1.out, at: abi.dataSizeOffset))
        guard (1...32).contains(ds) else { return nil }
        let type = String(bytes: r1.out[abi.dataTypeOffset..<abi.dataTypeOffset + 4],
                          encoding: .ascii) ?? "????"

        var buf2 = [UInt8](repeating: 0, count: abi.size)
        pack(key, into: &buf2)
        writeLE32(ds, at: abi.dataSizeOffset, into: &buf2)
        buf2[abi.cmdOffset] = 5         // SMC_CMD_READ_BYTES
        let r2 = call(buf2)
        guard r2.kr == KERN_SUCCESS, r2.out[abi.cmdOffset - 2] == 0 else { return nil }

        return (type, Array(r2.out[abi.bytesOffset..<abi.bytesOffset + ds]))
    }

    public static func temperatureC(_ key: String) -> Double? {
        guard let abi = discoverABI(),
              let r = readRaw(key, abi: abi),
              r.data.count >= 2,
              r.type.contains("78")      // sp78 (or its byte-reversed twin)
        else { return nil }
        let v = Double(Int8(bitPattern: r.data[0])) + Double(r.data[1]) / 256.0
        return (0...120).contains(v) ? v : nil
    }

    public static func batteryTemperatureC() -> Double? {
        for key in ["TB1T", "TB2T", "TB0T"] {
            if let t = temperatureC(key) { return t }
        }
        return nil
    }

    public static func probe(_ key: String) -> String {
        guard let abi = discoverABI() else { return "abi discovery failed" }
        guard let r = readRaw(key, abi: abi) else { return "no response (key missing or rejected)" }
        let hex = r.data.map { String(format: "%02x", $0) }.joined(separator: " ")
        var s = "type=\(r.type) data[\(r.data.count)]=\(hex)"
        if r.type.contains("78"), r.data.count >= 2 {
            let v = Double(Int8(bitPattern: r.data[0])) + Double(r.data[1]) / 256.0
            s += String(format: " -> %.1f°C", v)
        }
        return s
    }

    public static func abiDescription() -> String {
        if connection() == nil { return "no AppleSMC connection" }
        guard let a = discoverABI(verbose: true) else {
            return "SMC ABI discovery FAILED - probe trace above"
        }
        return "SMC ABI: struct=\(a.size)B cmd@\(a.cmdOffset) dataSize@\(a.dataSizeOffset) dataType@\(a.dataTypeOffset) bytes@\(a.bytesOffset)"
    }

    private static func readUInt32(_ key: String, abi: ABI) -> Int? {
        guard let r = readRaw(key, abi: abi), r.data.count == 4 else { return nil }
        return Int(le32(r.data, at: 0))
    }
    
    /// one-shot struct call with an arbitrary selector — probing only
    public static func rawStructCall(_ selector: UInt32, input: [UInt8]) -> (kr: kern_return_t, out: [UInt8]) {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != IO_OBJECT_NULL else { return (KERN_FAILURE, []) }
        defer { IOObjectRelease(service) }
        var c: io_connect_t = 0
        guard IOServiceOpen(service, mach_task_self_, 0, &c) == KERN_SUCCESS else { return (KERN_FAILURE, []) }
        defer { IOServiceClose(c) }

        var out = [UInt8](repeating: 0, count: input.count)
        var outSize = out.count
        let kr: kern_return_t = input.withUnsafeBytes { inRaw in
            out.withUnsafeMutableBytes { outRaw in
                IOConnectCallStructMethod(
                    c, selector,
                    inRaw.bindMemory(to: UInt8.self).baseAddress, input.count,
                    outRaw.bindMemory(to: UInt8.self).baseAddress, &outSize
                )
            }
        }
        return (kr, kr == KERN_SUCCESS ? out : [])
    }

    private static func pack(_ key: String, into buf: inout [UInt8]) {
        let bytes = Array(key.utf8)
        for i in 0..<4 { buf[i] = i < bytes.count ? bytes[i] : 0 }
    }
    private static func le32(_ buf: [UInt8], at o: Int) -> UInt32 {
        UInt32(buf[o]) | UInt32(buf[o + 1]) << 8 | UInt32(buf[o + 2]) << 16 | UInt32(buf[o + 3]) << 24
    }
    private static func writeLE32(_ v: Int, at o: Int, into buf: inout [UInt8]) {
        buf[o] = UInt8(v & 0xFF)
        buf[o + 1] = UInt8((v >> 8) & 0xFF)
        buf[o + 2] = UInt8((v >> 16) & 0xFF)
        buf[o + 3] = UInt8((v >> 24) & 0xFF)
    }
    private static func align4(_ v: Int) -> Int { (v + 3) & ~3 }
}
