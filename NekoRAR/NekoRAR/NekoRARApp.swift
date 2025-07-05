//
//  NekoRARApp.swift
//  NekoRAR
//
//  Created by 千葉牧人 on 2025/5/20.
//

import SwiftUI

@main
struct NekoRARApp: App {
    init() {
        if CommandLine.arguments.count > 1 {
            let path = CommandLine.arguments[1]
            UserDefaults.standard.set(path, forKey: "launchFilePath")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
