//
//  TransmitEncryption.swift
//  iLoveTranscode
//
//  Created by 唐梓皓 on 2024/2/13.
//

import Foundation
import CryptoKit
import Security
import AppKit

class TransmitEncryption {
    
    static public var privateKey: String = "iLoveTranscodeAndTranscodeHurtsMe"
    
    static private func getSystemUUID() -> String? {
        let platformExpert = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("IOPlatformExpertDevice")
        )
        guard platformExpert != 0 else { return nil }
        defer { IOObjectRelease(platformExpert) }
        
        return IORegistryEntryCreateCFProperty(
            platformExpert,
            kIOPlatformUUIDKey as CFString,
            kCFAllocatorDefault,
            0
        ).takeUnretainedValue() as? String
    }
    
    static public func renewPrivateKey() -> String {
        let systemID = getSystemUUID() ?? UUID().uuidString
        let uuID = UUID().uuidString
        let privateKey = "\(systemID)-\(uuID)"
        saveKeyToKeychain(key: "com.water-zi.iLoveTranscode-Server.mqttKey", value: privateKey) { result in
            print(result ? "成功写入新的密钥" : "密钥保存失败")
        }
        Task {
            await ContentView.ViewModel.shared.generateQRCode()
        }
        return privateKey
    }
    
    static func encryptStringWithKey(_ input: String, privateKey: String = privateKey) -> String? {
        guard let inputData = input.data(using: .utf8) else { return nil }
        let privateKeyData = hashStringUsingSHA256(privateKey)
        
        do {
            let symmetricKey = SymmetricKey(data: privateKeyData)
            let nonce = AES.GCM.Nonce()
            let sealedBox = try AES.GCM.seal(inputData, using: symmetricKey, nonce: nonce)
            let encryptedData = sealedBox.combined
            return encryptedData?.base64EncodedString()
        } catch {
            print("Encryption error:", error.localizedDescription)
            return nil
        }
    }

    static func decryptStringWithKey(_ encryptedString: String, privateKey: String = privateKey) -> String? {
        guard let encryptedData = Data(base64Encoded: encryptedString) else { return nil }
        let privateKeyData = hashStringUsingSHA256(privateKey)
        
        do {
            let symmetricKey = SymmetricKey(data: privateKeyData)
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            let decryptedData = try AES.GCM.open(sealedBox, using: symmetricKey)
            return String(data: decryptedData, encoding: .utf8)
        } catch {
            print("Decryption error:", error.localizedDescription)
            return nil
        }
    }
    
    static private func hashStringUsingSHA256(_ input: String) -> Data {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return Data(hashedData)
    }

    static private func saveKeyToKeychain(key: String, value: String, completion: @escaping (Bool) -> Void) {
        Task {
            if let data = value.data(using: .utf8) {
                let query: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrAccount as String: key,
                    kSecValueData as String: data
                ]
                
                // Delete any existing item with the same key before saving
                await withUnsafeContinuation { continuation in
                    SecItemDelete(query as CFDictionary)
                    continuation.resume(returning: ())
                }
                
                // Add the new item to the keychain
                let status = await withUnsafeContinuation { continuation in
                    let status = SecItemAdd(query as CFDictionary, nil)
                    continuation.resume(returning: status)
                }
                completion(status == errSecSuccess)
            } else {
                completion(false)
            }
        }
    }

    static public func readKeyFromKeychain(key: String, completion: @escaping (String?) -> Void) {
        Task {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key,
                kSecReturnData as String: kCFBooleanTrue!,
                kSecMatchLimit as String: kSecMatchLimitOne
            ]
            
            var result: AnyObject?
            let status = await withUnsafeContinuation { continuation in
                let status = SecItemCopyMatching(query as CFDictionary, &result)
                continuation.resume(returning: status)
            }
            
            if status == errSecSuccess {
                if let data = result as? Data, let value = String(data: data, encoding: .utf8) {
                    completion(value)
                    return
                }
            } else {
                await MainActor.run {
                    let alert = NSAlert()
                    alert.messageText = "您拒绝了APP访问钥匙串的请求"
                    alert.informativeText = "为了保存您的加密私钥，我们需要访问特定的钥匙串。如果您拒绝访问，私钥将在每次启动时更新。在这种情况下，您每次都需要在\"我爱转码\"APP中扫描二维码来更新客户端密钥。\n\n如您刚刚不慎点击拒绝，您可以在系统APP：\"钥匙串访问\"中搜索\"com.water-zi.iLoveTranscode-Server.mqttKey\"，右键选择\"显示简介\"，然后在\"访问控制\"中删除这个APP，最后点击\"存储更改\"。您将在下次启动APP时再次被要求输入密码。"
                    alert.addButton(withTitle: "复制搜索内容")
                    alert.addButton(withTitle: "再说吧")
                    
                    let result = alert.runModal()
                    
                    if result == .alertFirstButtonReturn {
                        NSPasteboard.general.clearContents()
                        let result = NSPasteboard.general.setString("com.water-zi.iLoveTranscode-Server.mqttKey", forType: .string)
                        print(result)
                    }
                }
            }
            completion(nil)
        }
    }

    
}

extension String {
    func encrypt() -> String {
        return TransmitEncryption.encryptStringWithKey(self) ?? ""
    }
    
    func decrypt() -> String {
        return TransmitEncryption.decryptStringWithKey(self) ?? ""
    }
}
