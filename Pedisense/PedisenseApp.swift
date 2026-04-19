//
//  PedisenseApp.swift
//  Pedisense
//
//  Created by Harry Pall on 2026-04-18.
//

import SwiftUI
import GoogleSignIn

@main
struct PedisenseApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
