//
//  AppDelegate.swift
//  iLoveTranscode_Server
//
//  Created by 唐梓皓 on 2024/2/16.
//

import Foundation
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        if UserDefaults.standard.object(forKey: "NotShowRequirePasswordReasonAlert") == nil ||
           UserDefaults.standard.bool(forKey: "NotShowRequirePasswordReasonAlert") == false
        {
            
            let alert = NSAlert()
            alert.messageText = "您可能会被要求输入登录密码\n为什么？"
            alert.informativeText = "为了保存您的加密私钥，我们需要访问特定的钥匙串。如果您拒绝访问，私钥将在每次启动时更新。在这种情况下，您每次都需要在\"我爱转码\"APP中扫描二维码来更新客户端密钥。\n\n为了避免每次都需要输入密码的麻烦，请在输入密码后点击\"始终允许\"。"
            alert.addButton(withTitle: "好的")
            alert.showsSuppressionButton = true
            alert.suppressionButton?.state = .on
            
            _ = alert.runModal()
            
            TransmitEncryption.readKeyFromKeychain(key: "com.water-zi.iLoveTranscode-Server.mqttKey", completion: { privateKey in
                TransmitEncryption.privateKey = privateKey ?? TransmitEncryption.renewPrivateKey()
            })
            UserDefaults.standard.setValue(alert.suppressionButton?.state == .on, forKey: "NotShowRequirePasswordReasonAlert")
        } else {
            TransmitEncryption.readKeyFromKeychain(key: "com.water-zi.iLoveTranscode-Server.mqttKey", completion: { privateKey in
                TransmitEncryption.privateKey = privateKey ?? TransmitEncryption.renewPrivateKey()
            })
        }
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let alert = NSAlert()
        alert.messageText = "确认退出发射器？"
        alert.informativeText = "退出发射器后，APP将无法收到任务更变通知，实时活动需重新订阅。"
        alert.addButton(withTitle: "退出")
        alert.addButton(withTitle: "取消")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // User clicked "Quit"
            return .terminateNow
        } else {
            // User clicked "Cancel"
            return .terminateCancel
        }
    }
}
