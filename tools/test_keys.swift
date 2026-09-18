import Foundation
import GlideCore

if let c = SMC.shared {
    print("CH0I:", (try? c.readKey("CH0I"))?.bytes ?? "missing")
    print("CH0B:", (try? c.readKey("CH0B"))?.bytes ?? "missing")
    print("CH0C:", (try? c.readKey("CH0C"))?.bytes ?? "missing")
    print("CHWA:", (try? c.readKey("CHWA"))?.bytes ?? "missing")
    print("BCLM:", (try? c.readKey("BCLM"))?.bytes ?? "missing")
    print("B0IF:", (try? c.readKey("B0IF"))?.bytes ?? "missing")
    print("ACLC:", (try? c.readKey("ACLC"))?.bytes ?? "missing")
}
