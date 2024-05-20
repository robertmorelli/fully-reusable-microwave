//
//  FullyReusableMicrowaveApp.swift
//  FullyReusableMicrowave
//
//  Created by Marco Puig on 5/15/24.
//

import SwiftUI

@main
struct FullyReusableMicrowaveApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .focusable()
                .onKeyPress(
                    phases: [.up, .down, .repeat],
                    action: 
                { keyPress in
                    if keyPress.phase == .up {
                        pressedKeys.remove(keyPress.key)
                    }
                    else if keyPress.phase == .down {
                        pressedKeys.insert(keyPress.key)
                    }
                    return .handled
                })
        }
    }
}
