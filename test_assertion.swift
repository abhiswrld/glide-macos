import Foundation
import IOKit.pwr_mgt

var assertionID: IOPMAssertionID = 0
let reasonForActivity = "Glide Battery Calibration" as CFString
let success = IOPMAssertionCreateWithName(
    kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
    IOPMAssertionLevel(kIOPMAssertionLevelOn),
    reasonForActivity,
    &assertionID
)
print("Assertion created: \(success == kIOReturnSuccess)")
if assertionID != 0 {
    IOPMAssertionRelease(assertionID)
}
