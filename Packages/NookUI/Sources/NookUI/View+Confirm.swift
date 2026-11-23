// Licensed under GPL-3.0. See LICENSE.
//
//  View+Confirm.swift
//  NookUI
//
//  FORK: the confirmation before something that cannot be undone. SwiftUI's confirmationDialog is drawn as clear glass
//  on macOS 26, and over a busy page the words and the red button could not be read. This is the system's own alert
//  sheet: a solid panel, Cancel the default so Return never deletes.
//

import SwiftUI
import AppKit

public extension View {
    /// Asks before `action` runs. `isPresented` is set to true to ask and is put back to false when it is answered.
    func nookConfirm(_ title: @escaping @autoclosure () -> String, message: @escaping @autoclosure () -> String,
                     confirm: String, isPresented: Binding<Bool>, destructive: Bool = true,
                     action: @escaping () -> Void) -> some View {
        onChange(of: isPresented.wrappedValue) { _, asking in
            guard asking else { return }
            let alert = NSAlert()
            alert.messageText = title()
            alert.informativeText = message()
            alert.alertStyle = destructive ? .warning : .informational
            alert.addButton(withTitle: "Cancel")
            alert.addButton(withTitle: confirm)
            alert.buttons[0].keyEquivalent = "\r"
            alert.buttons[1].keyEquivalent = ""
            // Not the red destructive tint: red on the alert's grey panel was the faintest thing on it. The warning icon and the
            // button's own words say what it does, and Cancel is the default.
            let finish: (NSApplication.ModalResponse) -> Void = { response in
                // The action first: some callers derive `isPresented` from the thing they act on.
                if response == .alertSecondButtonReturn { action() }
                isPresented.wrappedValue = false
            }
            if let window = NSApp.keyWindow ?? NSApp.mainWindow {
                alert.beginSheetModal(for: window, completionHandler: finish)
            } else {
                finish(alert.runModal())
            }
        }
    }
}
