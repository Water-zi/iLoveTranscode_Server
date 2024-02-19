//
//  iLoveTranscode_ServerApp.swift
//  iLoveTranscode_Server
//
//  Created by 唐梓皓 on 2024/2/4.
//

import SwiftUI

@main
struct iLoveTranscode_ServerApp: App {
    
    @NSApplicationDelegateAdaptor var appDelegate: AppDelegate
    
    @State var showStatusBarIconTips: Bool = UserDefaults.standard.bool(forKey: "DoNotShowStatusBarIconTipsAgain")
    @State var pushNotificationAnyway: Bool = UserDefaults.standard.bool(forKey: "PushNotificationAnyway")
    
    let persistenceController = PersistenceController.shared
    
    func setNeverShowAgain(_ sender: NSButton) {
        
    }

    var body: some Scene {
        WindowGroup {
            ContentView(isMenuView: false)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .onDisappear(perform: {
                    NSApplication.shared.setActivationPolicy(.accessory)
                    guard !UserDefaults.standard.bool(forKey: "DoNotShowStatusBarIconTipsAgain") else { return }
                    let alert = NSAlert()
                    alert.messageText = "发射器并未退出"
                    alert.informativeText = "您仍可以在状态栏中点击 \"i♡TC\" 以显示发射器主界面。按界面右下角\"退出\"或使用快捷键\"⌘Q\"以退出发射器。"
                    alert.addButton(withTitle: "好的")
                    alert.showsSuppressionButton = true
                    
                    _ = alert.runModal()
                    if alert.suppressionButton?.state == .on {
                        UserDefaults.standard.setValue(true, forKey: "DoNotShowStatusBarIconTipsAgain")
                    } else {
                        UserDefaults.standard.setValue(false, forKey: "DoNotShowStatusBarIconTipsAgain")
                    }
                })
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(action: {
                    let alert = NSAlert()
                    alert.messageText = "更新加密通信密钥？"
                    alert.informativeText = "您不必经常更新密钥，除非您觉得密钥被泄漏了。\n\n密钥更新后，以往在APP中扫描添加的项目都将不再可用，您需要在\"我爱转码\"APP中重新扫描二维码以更新密钥。"
                    alert.addButton(withTitle: "确认")
                    alert.addButton(withTitle: "取消")
                    
                    let response = alert.runModal()
                    if response == .alertFirstButtonReturn {
                        TransmitEncryption.privateKey = TransmitEncryption.renewPrivateKey()
                    }
                }, label: {
                    Text("更新密钥")
                })
                .keyboardShortcut("U", modifiers: [.shift, .command])
                
                Toggle(isOn: $pushNotificationAnyway.didSet(execute: { newValue in
                    pushNotificationAnyway = newValue
                    UserDefaults.standard.setValue(newValue, forKey: "PushNotificationAnyway")
                }), label: {
                    Text("即使没有订阅通知也推送")
                })
                .keyboardShortcut("P", modifiers: [.shift, .command])
            }
            
            
            CommandGroup(before: .windowSize) {
                Toggle(isOn: $showStatusBarIconTips.didSet(execute: { newValue in
                    showStatusBarIconTips = newValue
                    UserDefaults.standard.setValue(newValue, forKey: "DoNotShowStatusBarIconTipsAgain")
                })) {
                    Text("提示状态栏图标位置")
                }
                .keyboardShortcut("T", modifiers: [.command])
                Divider()
            }
        }
        
        MenuBarExtra {
            ContentView(isMenuView: true)
        } label: {
            Image(systemName: "magnifyingglass")
                .bold()
            Text("i♡TC")
        }
        .menuBarExtraStyle(.window)

    }
}
