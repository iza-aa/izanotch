//
//  ApplicationRelauncher.swift
//  boringNotch
//
//  Created by Corentin132 on 03/10/2025.
//

import AppKit

public enum ApplicationRelauncher {
    public static func restart() {
        let bundleURL = Bundle.main.bundleURL
        let pid = ProcessInfo.processInfo.processIdentifier
        
        // Authentic HeyClicky relaunch loop:
        // Wait until old process PID has exited before executing /usr/bin/open
        let script = "attempt=0; while kill -0 \"$1\" 2>/dev/null; do attempt=$((attempt + 1)); [ \"$attempt\" -lt 300 ] || exit 1; sleep 0.1; done; exec /usr/bin/open \"$2\""
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script, "izanotchy-relaunch", "\(pid)", bundleURL.path]
        try? process.run()
        
        // Terminate cleanly so process lock is yielded immediately
        NSApp.terminate(nil)
    }
}
