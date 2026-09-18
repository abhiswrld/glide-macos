import Foundation
@testable import GlideCore
let client = try! SMCClient()
let ch0b = try? client.readKey("CH0B")
let ch0c = try? client.readKey("CH0C")
let ch0i = try? client.readKey("CH0I")
print("CH0B:", ch0b != nil ? "Exists" : "No")
print("CH0C:", ch0c != nil ? "Exists" : "No")
print("CH0I:", ch0i != nil ? "Exists" : "No")
