//
//  DetectHandwrittenDigitDemoApp.swift
//  DetectHandwrittenDigitDemo
//
//  Created by Wei-Cheng Ling on 2020/12/21.
//

import SwiftUI

@main
struct DetectHandwrittenDigitDemoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
