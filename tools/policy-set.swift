import Foundation

// class name must match powerd's archive exactly
@objc(ChargeCtrlPolicy)
final class ChargeCtrlPolicy: NSObject, NSSecureCoding {
    var drain: Bool = false
    var isEndOfCharge: Bool = false
    var noChargeToFull: Bool = false
    var owner: Int = 0
    var reason: String = ""
    var soclimit: Int = 0
    var terminated: Bool = false
    var token: UUID = UUID()

    static var supportsSecureCoding: Bool { true }

    func encode(with coder: NSCoder) {
        coder.encode(drain, forKey: "drain")
        coder.encode(isEndOfCharge, forKey: "isEndOfCharge")
        coder.encode(noChargeToFull, forKey: "noChargeToFull")
        coder.encode(owner, forKey: "owner")
        coder.encode(reason, forKey: "reason")
        coder.encode(soclimit, forKey: "soclimit")
        coder.encode(terminated, forKey: "terminated")
        coder.encode(token, forKey: "token")
    }

    init?(coder: NSCoder) {
        drain = coder.decodeBool(forKey: "drain")
        isEndOfCharge = coder.decodeBool(forKey: "isEndOfCharge")
        noChargeToFull = coder.decodeBool(forKey: "noChargeToFull")
        owner = coder.decodeInteger(forKey: "owner")
        reason = coder.decodeObject(of: NSString.self, forKey: "reason") as String? ?? ""
        soclimit = coder.decodeInteger(forKey: "soclimit")
        terminated = coder.decodeBool(forKey: "terminated")
        token = coder.decodeObject(of: NSUUID.self, forKey: "token") as UUID? ?? UUID()
        super.init()
    }
}

guard geteuid() == 0 else { print("run with sudo"); exit(1) }
guard CommandLine.arguments.count > 1,
      let target = Int(CommandLine.arguments[1]),
      (40...100).contains(target) else {
    print("usage: sudo swift policy-set.swift <40...100>"); exit(1)
}

let path = "/Library/Preferences/com.apple.powerd.charging.plist"
let url = URL(fileURLWithPath: path)

// 1. backup, always
let ts = Int(Date().timeIntervalSince1970)
let backup = "/tmp/glide-charging-backup-\(ts).plist"
try! FileManager.default.copyItem(atPath: path, toPath: backup)
print("backup: \(backup)")

// 2. read outer plist, pull the blob
guard let outer = NSDictionary(contentsOf: url),
      let blob = outer["policies"] as? Data else { print("cannot read policies blob"); exit(1) }

// 3. unarchive powerd's policies into our class
let un = try! NSKeyedUnarchiver(forReadingFrom: blob)
un.requiresSecureCoding = true
un.setClass(ChargeCtrlPolicy.self, forClassName: "ChargeCtrlPolicy")
guard let policies = un.decodeObject(of: [NSArray.self, ChargeCtrlPolicy.self],
                                     forKey: NSKeyedArchiveRootObjectKey) as? [ChargeCtrlPolicy],
      !policies.isEmpty else { print("decode failed or empty"); exit(1) }

for p in policies { print("before: soclimit=\(p.soclimit) reason=\(p.reason) terminated=\(p.terminated)") }
for p in policies where !p.terminated { p.soclimit = target }
for p in policies { print("after : soclimit=\(p.soclimit) reason=\(p.reason) terminated=\(p.terminated)") }

// 4. re-archive, write back binary, keep perms
let newBlob = try! NSKeyedArchiver.archivedData(withRootObject: policies, requiringSecureCoding: true)
let newOuter = NSMutableDictionary(dictionary: outer)
newOuter["policies"] = newBlob
let data = try! PropertyListSerialization.data(fromPropertyList: newOuter, format: .binary, options: 0)
try! data.write(to: url, options: .atomic)
try! FileManager.default.setAttributes(
    [.posixPermissions: 0o644, .ownerAccountName: "root", .groupOwnerAccountName: "wheel"],
    ofItemAtPath: path)
print("wrote soclimit=\(target)")