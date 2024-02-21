//
//  APNSServer.swift
//  iLoveTranscode_Server
//
//  Created by 唐梓皓 on 2024/2/12.
//

import Foundation
import SwiftJWT
import CryptorECC


struct APNSNotification {
    let deviceToken: String
    let payload: [String: Any]
}

struct NotificationAlert {
    let title: String
    let subTitle: String?
    let body: String
    let sound: String = "default"
    
    func getString() -> String {
        return
"""
    "alert": {
    "title": "\(title)",
    \(subTitle != nil ? subTitle! : "")
    "body": "\(body)",
    "sound": "\(sound)"
},
"""
    }
}

class APNSServer {
    // Function to send a notification request to APNs
    static let shared = APNSServer()
    private init() {}
    
    private var token: String?
    private var tokenIat: Date?
    
    public var lastInfoString: String = ""
    
    class DelayEndActivity {
        private var workItem: DispatchWorkItem?

        func runAfterDelay(_ delay: TimeInterval, _ action: @escaping () -> Void) {
            let deadline = DispatchTime.now() + delay
            let workItem = DispatchWorkItem {
                action()
            }
            DispatchQueue.main.asyncAfter(deadline: deadline, execute: workItem)
            self.workItem = workItem
        }

        func cancel() {
            workItem?.cancel()
        }
    }
    private var delayEndActivity: DelayEndActivity?
    
    let sessionDataTask: (Data?, URLResponse?, Error?) -> Void = { data, response, error in
        if let error = error {
            print("Error sending notification request: \(error)")
            return
        }
        
        // Handle response
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode != 200 {
                print("Status code: \(httpResponse.statusCode)")
            }
        }
        
        if let responseData = data {
            if responseData.count > 0 {
                print("Response data: \(String(data: responseData, encoding: .utf8) ?? "")")
            }
        }
    }
    
    func sendConnectionBuildNotification(deviceToken: String) {
        let payload =
            """
                {
                    "aps": {
                        "alert": {
                            "title": "设备密钥已安全送达",
                            "body": "服务端已收到您的密钥，在任务状态改变时将立即通知您。"
                        },
                        "sound": "default",
                        "thread-id": "ConnectionEstablishedNotification"
                    }
                }
            """.data(using: .utf8)!
        
        // Create an URL for APNs endpoint
#if DEBUG
        let url = URL(string: "https://api.sandbox.push.apple.com/3/device/\(deviceToken)")!
#else
        let url = URL(string: "https://api.push.apple.com/3/device/\(deviceToken)")!
#endif
        
        // Create a URLSession
        let session = URLSession(configuration: .default)
        
        // Prepare the request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = payload
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add authorization header with bearer token (JWT)
        let authorizationToken = createJWT()
        request.addValue("bearer \(authorizationToken)", forHTTPHeaderField: "Authorization")
        request.addValue("com.water-zi.iLoveTranscode", forHTTPHeaderField: "apns-topic")
        request.addValue("alert", forHTTPHeaderField: "apns-push-type")
        request.addValue("5", forHTTPHeaderField: "apns-priority")
        
        
        // Perform the request
        let task = session.dataTask(with: request, completionHandler: sessionDataTask)
        
        task.resume()
    }
    
    func sendLiveActivityUpdateNotification(activityToken: String, infoString: String, alert: NotificationAlert?) {
        if let delayEndActivity = delayEndActivity {
            delayEndActivity.cancel()
        }
        lastInfoString = infoString
        let payload =
            """
                {
                    "aps": {
                        "timestamp": \(Int(Date().timeIntervalSince1970)),
                        "event": "update",
                        "content-state": \(infoString),
                        \(alert != nil ? alert!.getString() : "")
                        "thread-id": "ProjectInfoLiveActivityNotification"
                    }
                }
            """.data(using: .utf8)!
        
        // Create an URL for APNs endpoint
#if DEBUG
        let url = URL(string: "https://api.sandbox.push.apple.com/3/device/\(activityToken)")!
#else
        let url = URL(string: "https://api.push.apple.com/3/device/\(activityToken)")!
#endif
        
        // Create a URLSession
        let session = URLSession(configuration: .default)
        
        // Prepare the request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = payload
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add authorization header with bearer token (JWT)
        let authorizationToken = createJWT()
        request.addValue("bearer \(authorizationToken)", forHTTPHeaderField: "Authorization")
        request.addValue("com.water-zi.iLoveTranscode.push-type.liveactivity", forHTTPHeaderField: "apns-topic")
        request.addValue("liveactivity", forHTTPHeaderField: "apns-push-type")
        request.addValue("5", forHTTPHeaderField: "apns-priority")
        
        // Perform the request
        let task = session.dataTask(with: request, completionHandler: sessionDataTask)
        
        task.resume()
    }
    
    func sendLiveActivityEndNotification(activityToken: String, infoString: String) {
        lastInfoString = infoString
        let payload =
            """
                {
                    "aps": {
                        "timestamp": \(Int(Date().timeIntervalSince1970)),
                        "event": "update",
                        "content-state": \(infoString),
                        "thread-id": "ProjectInfoLiveActivityNotification"
                    }
                }
            """.data(using: .utf8)!
        
        // Create an URL for APNs endpoint
#if DEBUG
        let url = URL(string: "https://api.sandbox.push.apple.com/3/device/\(activityToken)")!
#else
        let url = URL(string: "https://api.push.apple.com/3/device/\(activityToken)")!
#endif
        
        // Create a URLSession
        let session = URLSession(configuration: .default)
        
        // Prepare the request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = payload
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add authorization header with bearer token (JWT)
        let authorizationToken = createJWT()
        request.addValue("bearer \(authorizationToken)", forHTTPHeaderField: "Authorization")
        request.addValue("com.water-zi.iLoveTranscode.push-type.liveactivity", forHTTPHeaderField: "apns-topic")
        request.addValue("liveactivity", forHTTPHeaderField: "apns-push-type")
        request.addValue("5", forHTTPHeaderField: "apns-priority")
        
        // Perform the request
        let task = session.dataTask(with: request, completionHandler: sessionDataTask)
        
        task.resume()
        
        self.delayEndActivity = DelayEndActivity()
        self.delayEndActivity?.runAfterDelay(5 * 60, {
            let payload =
                """
                    {
                        "aps": {
                            "timestamp": \(Int(Date().timeIntervalSince1970)),
                            "event": "end",
                            "content-state": \(infoString),
                            "thread-id": "ProjectInfoLiveActivityNotification"
                        }
                    }
                """.data(using: .utf8)!
            
            // Create an URL for APNs endpoint
    #if DEBUG
            let url = URL(string: "https://api.sandbox.push.apple.com/3/device/\(activityToken)")!
    #else
            let url = URL(string: "https://api.push.apple.com/3/device/\(activityToken)")!
    #endif
            
            // Create a URLSession
            let session = URLSession(configuration: .default)
            
            // Prepare the request
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = payload
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            
            // Add authorization header with bearer token (JWT)
            let authorizationToken = self.createJWT()
            request.addValue("bearer \(authorizationToken)", forHTTPHeaderField: "Authorization")
            request.addValue("com.water-zi.iLoveTranscode.push-type.liveactivity", forHTTPHeaderField: "apns-topic")
            request.addValue("liveactivity", forHTTPHeaderField: "apns-push-type")
            request.addValue("5", forHTTPHeaderField: "apns-priority")
            
            // Perform the request
            let task = session.dataTask(with: request, completionHandler: self.sessionDataTask)
            
            task.resume()
        })
    }
    
    func sendEndOfRenderNotification(deviceToken: String, alert: NotificationAlert) {
        let payload =
            """
                {
                    "aps": {
                        \(alert.getString())
                        "sound": "default",
                        "thread-id": "EndOfRenderNotification"
                    }
                }
            """.data(using: .utf8)!
        
        // Create an URL for APNs endpoint
#if DEBUG
        let url = URL(string: "https://api.sandbox.push.apple.com/3/device/\(deviceToken)")!
#else
        let url = URL(string: "https://api.push.apple.com/3/device/\(deviceToken)")!
#endif
        
        // Create a URLSession
        let session = URLSession(configuration: .default)
        
        // Prepare the request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = payload
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add authorization header with bearer token (JWT)
        let authorizationToken = createJWT()
        request.addValue("bearer \(authorizationToken)", forHTTPHeaderField: "Authorization")
        request.addValue("com.water-zi.iLoveTranscode", forHTTPHeaderField: "apns-topic")
        request.addValue("alert", forHTTPHeaderField: "apns-push-type")
        request.addValue("5", forHTTPHeaderField: "apns-priority")
        
        
        // Perform the request
        let task = session.dataTask(with: request, completionHandler: sessionDataTask)
        
        task.resume()
    }
    
    func createJWT() -> String {
        
        let now = getLastFullHourOrHalfHour()
        if now == tokenIat, let token = token {
            return token
        }
        
        let header = Header(kid: "5QU2A4PFQZ")
        let claims = ClaimsStandardJWT(iss: "ZVDC8DS264", iat: now)
        
        var jwt = JWT(header: header, claims: claims)
        
        /* MARK: There will be an error here, complaining that parameter: key is undefined.
         I cannot give you my private key. If you want to use APNs, you should generate your own key at Apple's developer website.
         I think you can definitely understand what I mean. 😎
         If you want to make the code work and you dont care about APNs, uncomment the code below.
         */
        
        // let key = ""
        
        let pk = try! ECPrivateKey(key: key)
        
        let jwtSigner = JWTSigner.es256(privateKey: pk.pemString.data(using: .utf8)!)
        do {
            let signedJWT = try jwt.sign(using: jwtSigner)
            tokenIat = now
            token = signedJWT.value
            return signedJWT.value
        } catch {
            print(error.localizedDescription)
            return "signedJWT.value"
        }
    }
    
    func getLastFullHourOrHalfHour() -> Date {
        let calendar = Calendar.current
        let now = Date()
        let minute = calendar.component(.minute, from: now)
        let minuteInterval = 30 // Interval for half-hour
        
        var components = calendar.dateComponents([.year, .month, .day, .hour], from: now)
        
        // If it's past the half-hour mark, move to the last half-hour
        if minute >= minuteInterval {
            components.minute = minuteInterval
        } else {
            // Otherwise, move to the last hour
            components.minute = 0
        }
        
        if let lastHourOrHalfHour = calendar.date(from: components) {
            return lastHourOrHalfHour
        } else {
            return now
        }
    }
}
