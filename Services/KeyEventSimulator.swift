import CoreGraphics
import ApplicationServices
import Foundation

enum KeyEventSimulator {
    // keyCode 123 = Left Arrow, 124 = Right Arrow
    static func simulate(action: MappingAction) {
        switch action {
        case .desktopLeft:
            runShellAppleScript("key code 123 using control down")
            return
        case .desktopRight:
            runShellAppleScript("key code 124 using control down")
            return
        default:
            break
        }

        guard let keyCode = action.keyCode else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            let flags = action.modifierFlags ?? []
            if !flags.isEmpty {
                simulateWithAppleScript(keyCode: keyCode, modifiers: flags)
            } else {
                simulateWithCGEvent(keyCode: keyCode, modifiers: flags)
            }
        }
    }

    private static func runShellAppleScript(_ command: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", "tell application \"System Events\" to \(command)"]
        try? process.run()
    }

    private static func postSystemKeyEvent(keyCode: CGKeyCode, modifiers: CGEventFlags) {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        keyDown?.flags = modifiers
        keyDown?.post(tap: .cgSessionEventTap)

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        keyUp?.flags = modifiers
        keyUp?.post(tap: .cgSessionEventTap)
    }

    private static func simulateWithAppleScript(keyCode: CGKeyCode, modifiers: CGEventFlags) {
        var usingParts: [String] = []
        if modifiers.contains(.maskAlternate) { usingParts.append("option down") }
        if modifiers.contains(.maskControl) { usingParts.append("control down") }
        if modifiers.contains(.maskShift) { usingParts.append("shift down") }
        if modifiers.contains(.maskCommand) { usingParts.append("command down") }

        let usingClause = usingParts.isEmpty ? "" : " using \(usingParts.joined(separator: ", "))"
        let source = "tell application \"System Events\" to key code \(keyCode)\(usingClause)"

        let script = NSAppleScript(source: source)
        var error: NSDictionary?
        script?.executeAndReturnError(&error)

        if error != nil {
            simulateWithCGEvent(keyCode: keyCode, modifiers: modifiers)
        }
    }

    private static func simulateWithCGEvent(keyCode: CGKeyCode, modifiers: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        keyDown?.flags = modifiers
        keyDown?.post(tap: .cghidEventTap)

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        keyUp?.flags = modifiers
        keyUp?.post(tap: .cghidEventTap)
    }
}
