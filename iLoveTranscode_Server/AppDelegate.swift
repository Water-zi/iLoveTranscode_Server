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
                Task {
                    await ContentView.ViewModel.shared.generateQRCode()
                }
            })
            UserDefaults.standard.setValue(alert.suppressionButton?.state == .on, forKey: "NotShowRequirePasswordReasonAlert")
        } else {
            TransmitEncryption.readKeyFromKeychain(key: "com.water-zi.iLoveTranscode-Server.mqttKey", completion: { privateKey in
                TransmitEncryption.privateKey = privateKey ?? TransmitEncryption.renewPrivateKey()
                Task {
                    await ContentView.ViewModel.shared.generateQRCode()
                }
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
            if let activityToken = ContentView.ViewModel.shared.activityToken {
                let payload =
                    """
                        {
                            "aps": {
                                "timestamp": \(Int(Date().timeIntervalSince1970)),
                                "event": "end",
                                "content-state": \(APNSServer.shared.lastInfoString),
                                "thread-id": "ProjectInfoLiveActivityNotification"
                            }
                        }
                    """.data(using: .utf8)!
                
                // Create an URL for APNs endpoint
                let url = URL(string: "https://api\(APNSServer.shared.isDebugEnv ? ".sandbox" : "").push.apple.com/3/device/\(activityToken)")!
                
                // Create a URLSession
                let session = URLSession(configuration: .default)
                
                // Prepare the request
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.httpBody = payload
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                
                // Add authorization header with bearer token (JWT)
                let authorizationToken = APNSServer.shared.createJWT()
                request.addValue("bearer \(authorizationToken)", forHTTPHeaderField: "Authorization")
                request.addValue("com.water-zi.iLoveTranscode.push-type.liveactivity", forHTTPHeaderField: "apns-topic")
                request.addValue("liveactivity", forHTTPHeaderField: "apns-push-type")
                request.addValue("5", forHTTPHeaderField: "apns-priority")
                
                // Perform the request
                let task = session.dataTask(with: request, completionHandler: APNSServer.shared.sessionDataTask)
                
                task.resume()
            }
            if ContentView.ViewModel.shared.lastIsRendering,
               let deviceToken = ContentView.ViewModel.shared.deviceToken {
                let payload =
                    """
                        {
                            "aps": {
                                \(NotificationAlert(title: "我爱转码·发射器已退出", subTitle: nil, body: "发射器在任务未完成时退出，任务状态将不再更新，敬请留意。").getString())
                                "sound": "default",
                                "thread-id": "ServerQuitNotification"
                            }
                        }
                    """.data(using: .utf8)!
                
                // Create an URL for APNs endpoint
                let url = URL(string: "https://api\(APNSServer.shared.isDebugEnv ? ".sandbox" : "").push.apple.com/3/device/\(deviceToken)")!
                
                // Create a URLSession
                let session = URLSession(configuration: .default)
                
                // Prepare the request
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.httpBody = payload
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                
                // Add authorization header with bearer token (JWT)
                let authorizationToken = APNSServer.shared.createJWT()
                request.addValue("bearer \(authorizationToken)", forHTTPHeaderField: "Authorization")
                request.addValue("com.water-zi.iLoveTranscode", forHTTPHeaderField: "apns-topic")
                request.addValue("alert", forHTTPHeaderField: "apns-push-type")
                request.addValue("5", forHTTPHeaderField: "apns-priority")
                
                
                // Perform the request
                let task = session.dataTask(with: request, completionHandler: APNSServer.shared.sessionDataTask)
                
                task.resume()
            }
            return .terminateNow
        } else {
            return .terminateCancel
        }
    }
}
