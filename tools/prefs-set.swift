import Foundation

guard geteuid() == 0 else { print("run with sudo"); exit(1) }
let path = "/Library/Preferences/com.apple.powerd.charging.plist"
let url = URL(fileURLWithPath: path)
guard let outer = NSDictionary(contentsOf: url),
      let blob = outer["policies"] as? Data else { print("cannot read blob"); exit(1) }

let domain = "com.apple.powerd.charging" as CFString
CFPreferencesSetValue("policies" as CFString, blob as CFData,
                      domain, kCFPreferencesAnyUser, kCFPreferencesCurrentHost)
let ok = CFPreferencesSynchronize(domain, kCFPreferencesAnyUser, kCFPreferencesCurrentHost)
print("synchronized: \(ok)")

if let back = CFPreferencesCopyValue("policies" as CFString, domain,
                                     kCFPreferencesAnyUser, kCFPreferencesCurrentHost) as? Data {
    print("cfprefsd now serves \(back.count) bytes · matches disk: \(back == blob)")
} else {
    print("cfprefsd has no value for policies")
}