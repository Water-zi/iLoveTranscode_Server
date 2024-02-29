//
//  ResolveTCPConnection.swift
//  iLoveTranscode_Server
//
//  Created by 唐梓皓 on 2024/2/23.
//

import Foundation
import Network


class ResolveApp: NSObject {
    
    static let shared: ResolveApp = ResolveApp()
    private override init() {
        //
    }
    
    var conn: NWConnection?
        var number: UInt32 = 2
        
        init(conn: NWConnection?, number: UInt32) {
            self.conn = conn
            self.number = number
        }
        
        static let startNumber: UInt32 = 2
        
    
    
    
    
    
    
    
    
    
    
        func newApp() {
            let host = NWEndpoint.Host.ipv4(IPv4Address("127.0.0.1")!)
            let port = NWEndpoint.Port.init(integerLiteral: 1144)
            let conn = NWConnection(host: host, port: port, using: .tcp)
            
            conn.stateUpdateHandler = { newState in
                print(newState)
                if newState == .ready {
                    let str = "bQAAAAEAAACQAAAAAQAAAAEAAAAAAAAAAAAAAAAAAAAAAAAACgAAAAMAAAABAAAAAAAAAAAAAAACAAAARmluZEhvc3QAAQAwAAAAAAAAAPA/AgAAAFJlc29sdmUAAQAwAAAAAAAAAABAAAAAAA=="
                    let data = Data(base64Encoded: str)
                    conn.send(content: data, completion: NWConnection.SendCompletion.contentProcessed({ error in
                        print("Error: \(error)")
                    }))
                    self.receiveData()
                }
            }
            
            self.conn = conn
            
            conn.start(queue: .main)
            
            
        }
    
    private func receiveData() {
        conn?.receive(minimumIncompleteLength: 1, maximumLength: 65535) { data, _, isComplete, error in
                    if let data = data, !data.isEmpty {
                        // Handle received data
                        let receivedString = String(data: data, encoding: .ascii)
                        
                        print("Received data: \(receivedString ?? "Invalid UTF-8 data")")
                        
                        let searchPattern  = "Port\0".data(using: .ascii)!
                        guard let range = data.range(of: searchPattern) else {
                                print("Substring 'Port\\0' not found.")
                                return
                            }
                        guard range.upperBound + 8 <= data.endIndex else {
                                print("Not enough bytes after 'Port\\0' to extract.")
                                return
                            }
                        // Extract 8 bytes after the found pattern
                        let startIndex = range.upperBound + 4
                            let endIndex = data.index(startIndex, offsetBy: 8)
                            let extractedBytes = Array(data[startIndex..<endIndex])
                        
                        let byteArray = extractedBytes

                        // Convert the byte array to an Int64
                        let int64Value = byteArray.withUnsafeBytes {
                            $0.load(as: Double.self)
                        }

                        print(int64Value) // Output: 81985529216486895
                        
                        self.conn?.cancel()
                        
                            let host = NWEndpoint.Host.ipv4(IPv4Address("127.0.0.1")!)
                        let port = NWEndpoint.Port.init(integerLiteral: .init(truncating: int64Value as NSNumber))
                            let conn = NWConnection(host: host, port: port, using: .tcp)
                            
                            conn.stateUpdateHandler = { newState in
                                print(newState)
                                if newState == .ready {
                                    let str = "sAAAAAEAAACQAAAAAQAAAAIAAAAAAAAAAAAAAAAAAAAAAAAACgAAAAQAAAABAAAAAAAAAAAAAAACAAAAX19Db25uZWN0AAEAMAAAAAAAAADwPwIAAABmdXNpb25zY3JpcHQAAQAwAAAAAAAAAABAAgAAADZkOGI3YTUwLTc2NzMtNDNkNy1hN2VmLTk4ZDhiZDFhNDg1OAABADAAAAAAAAAACEABACAAAAAAAMDa80A="
                                    let data = Data(base64Encoded: str)
                                    conn.send(content: data, completion: NWConnection.SendCompletion.contentProcessed({ error in
                                        print("Error: \(error)")
                                    }))
                                    self.receiveData()
                                }
                            }
                            
                            self.conn = conn
                            
                            conn.start(queue: .main)
                        
                        
                        
                    }

                    if let error = error {
                        print("Error receiving data: \(error)")
                    }

                    if !isComplete {
                        self.receiveData() // Continue receiving data
                    } else {
                        print("Received all data")
                    }
                }
    }
        
        func close() {
            conn?.cancel()
        }
        
//        func getResolve() -> Object? {
//            connect()
//            return getResolve()
//        }
        
        private func connect() -> Table {
            // Implement your connection logic here
            return Table()
        }
        
//        private func getResolve() -> Object? {
//            // Implement your resolve logic here
//            return Object()
//        }
        
        func callMemberFunction(name: String, args: [Value]) -> Value {
            // Implement your call member function logic here
            return Value()
        }
        
        func callFunction(objectID: UInt32, name: String, args: [Value]) -> Value {
            // Implement your call function logic here
            return Value()
        }
        
        func sendPacket(header: PacketHeader, packet: [UInt8]) -> [UInt8] {
            // Implement your send packet logic here
            return [UInt8]()
        }
    
    struct Object {
        // Define your Object structure here
    }

    struct Value {
        // Define your Value structure here
    }

    struct PacketHeader {
        // Define your PacketHeader structure here
    }

    struct Table {
        // Define your Table structure here
    }
    
}

extension ResolveApp: NetServiceDelegate {
    func netServiceDidResolveAddress(_ sender: NetService) {
        print(sender)
    }
    
    func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
        print(errorDict)
    }
}
