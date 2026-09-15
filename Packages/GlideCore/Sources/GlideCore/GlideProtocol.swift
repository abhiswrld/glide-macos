//
//  GlideProtocol.swift
//  GlideCore
//
//  Created by Abhinav on 9/15/26.
//

import Foundation

/// The link between the Glide app and the glide-daemon.
/// Both sides link GlideCore and use this exact protocol.
@objc public protocol GlideDaemonProtocol {
    /// set the charge limit (60...100, multiples of 5). returns nil on success, error string on failure
    func setLimit(_ limit: Int, withReply reply: @escaping (String?) -> Void)
    /// current charge limit, -1 if unreadable
    func getLimit(withReply reply: @escaping (Int) -> Void)
    /// daemon liveness check
    func ping(withReply reply: @escaping (String) -> Void)
}

public enum GlideXPC {
    /// the mach service name the daemon registers with launchd
    public static let serviceName = "com.abhiswrld.glide.daemon"
}
