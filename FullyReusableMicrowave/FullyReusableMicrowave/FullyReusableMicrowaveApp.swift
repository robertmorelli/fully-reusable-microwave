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
                    switch keyPress.phase {
                    case .up:
                        pressedKeys.remove(keyPress.key)
                    case .down:
                        pressedKeys.insert(keyPress.key)
                    default:
                        break
                    }
                    return .handled
                })
        }
    }
}
