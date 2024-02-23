//
//  ContentViewModel.swift
//  iLoveTranscode_Server
//
//  Created by 唐梓皓 on 2024/2/4.
//

import SwiftUI
import Foundation
import CocoaMQTT
import PythonKit
import Python

struct MQTTBlocker: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var address: String
    var port: UInt16?
    var tlsPort: UInt16?
    var name: String
    
    static let Mosquitto = MQTTBlocker(address: "test.mosquitto.org", port: 1883, tlsPort: nil, name: "Mosquitto")
    static let HiveMQ = MQTTBlocker(address: "broker.hivemq.com", port: 1883, tlsPort: nil, name: "HiveMQ")
    static let Fluux = MQTTBlocker(address: "mqtt.fluux.io", port: 1883, tlsPort: nil, name: "Fluux")
    static let EMQX = MQTTBlocker(address: "broker.emqx.io", port: 1883, tlsPort: nil, name: "EMQX")
    static let Custom = MQTTBlocker(address: "", port: 1883, tlsPort: 8883, name: "Custom...")
}

struct ProjectQRCodeInfo: Codable {
    var projectName: String
    var brokerAddress: String
    var brokerPort: UInt16
    var topicAddress: String
    var privateKey: String
}

enum MQTTConnectionState {
    case disconnected, connected, subscribe
    
    var color: Color {
        switch self {
        case .disconnected:
            return .red
        case .connected:
            return .orange
        case .subscribe:
            return .green
        }
    }
}

struct RenderJobSelectionInfo {
    var jobID: String
    var jobName: String
    var timelineName: String
    var status: JobStatus
    var order: Int
}

enum GetResolveError: Error {
    case notInstalled, notOpened
}

extension ContentView {
    
    @MainActor
    class ViewModel: ObservableObject {
        
        static let shared: ViewModel = ViewModel()
        private init() {}
        
        @Published var selectedBlocker: MQTTBlocker = MQTTBlocker.Mosquitto
        //        @Published var selectedCustomBlocker: Bool = false
        @Published var customBlockerAddress: String = ""
        @Published var customBlockerPort: String = ""
        @Published var usingTLS: Bool = false
        @Published var showAlertOfUsingTLS: Bool = false
        let mqttBlockers: [MQTTBlocker] = [
            MQTTBlocker.Mosquitto,
            MQTTBlocker.HiveMQ,
            MQTTBlocker.Fluux,
            MQTTBlocker.EMQX,
            MQTTBlocker.Custom
        ]
        
        var mqtt: CocoaMQTT5?
        @Published var connectedToMQTTServer: MQTTConnectionState = .disconnected
        
        @Published var canRetryGetProject: Bool = false
        @Published var projectName: String = ""
        private var projectId: String = ""
        
        private var publishTopic: String = ""
        
        @Published var qrCodeImage: CGImage?
        
        private var publishTimer: Timer?
        
        //        @Published var lastCommand: String = "Latest Command Will be Display Here."
        @Published var deviceTokens: Set<String> = Set<String>()
        @Published var activityTokens: Set<String> = Set<String>()
        private var lastActivityInfo: [String : ProjectInfoToWidget?] = [:]
        @Published private(set) var lastIsRendering: Bool = false
        
        @Published var renderJobsSelectionList: [String : RenderJobSelectionInfo] = [:]
        @Published var renderJobsButtonDisabled: Bool = false
        
        // Detect job delete
        private var lastRenderJobList: [JobBasicInfo]?
        
        func tryToGetProject(loop: Bool) async -> GetResolveError? {
            guard Resolve.shared.davinciInstalled,
                  let dvr = Resolve.shared.sys?.modules["fusionscript"].scriptapp("Resolve"),
                  let projectMangerFunc = dvr.checking[dynamicMember: "GetProjectManager"],
                  let projectManager = try? projectMangerFunc.throwing.dynamicallyCall(withArguments: []),
                  let currentProjectFunc = projectManager.checking[dynamicMember: "GetCurrentProject"],
                  let currentProject = try? currentProjectFunc.throwing.dynamicallyCall(withArguments: []),
                  let getNameFunc = currentProject.checking[dynamicMember: "GetName"],
                  let name = try? getNameFunc.throwing.dynamicallyCall(withArguments: []),
                  let getIdFunc = currentProject.checking[dynamicMember: "GetUniqueId"],
                  let id = try? getIdFunc.throwing.dynamicallyCall(withArguments: [])
            else {
                guard Resolve.shared.davinciInstalled
                else {
                    return .notInstalled
                }
                projectName = ""
                qrCodeImage = nil
                mqtt?.disconnect()
                print("DVR, PM and Project Not Found")
                await MainActor.run {
                    self.canRetryGetProject = true
                }
                guard loop else { return .notOpened }
                
                let result = try? await withCheckedThrowingContinuation { (continuation: CheckedContinuation<GetResolveError?, Error>) in
                    Task {
                        try? await Task.sleep(for: .seconds(1))
                        let projectStatus = await tryToGetProject(loop: true)
                        continuation.resume(returning: projectStatus)
                    }
                }
                return result
            }
            Resolve.shared.projectManager = projectManager
            Resolve.shared.currentProject = currentProject
            
            publishTopic = "iLoveTranscode/\(id)"
            projectId = String(id) ?? ""
            await MainActor.run {
                self.canRetryGetProject = false
                self.projectName = String(name) ?? "获取项目名称失败"
            }
            if mqtt?.connState == .connected {
                mqtt?.subscribe([MqttSubscription(topic: "\(publishTopic)/inverse")])
            } else {
                self.connectToMQTTBlocker()
            }
            return nil
        }
        
        func connectToMQTTBlocker() {
            var host: String
            var port: UInt16
            var usingTLS: Bool
            if self.selectedBlocker == .Custom {
                host = self.customBlockerAddress
                port = UInt16(UInt(self.customBlockerPort) ?? 1883)
                usingTLS = self.usingTLS
            } else {
                let blocker = self.selectedBlocker
                host = blocker.address
                port = blocker.tlsPort ?? blocker.port ?? 1883
                usingTLS = blocker.tlsPort != nil
            }
            connectedToMQTTServer = .disconnected
            mqtt = CocoaMQTT5(clientID: UUID().uuidString, host: host, port: port)
            guard let mqtt = mqtt else { return }
            
            let connectProperties = MqttConnectProperties()
            connectProperties.topicAliasMaximum = 0
            connectProperties.sessionExpiryInterval = 0
            connectProperties.receiveMaximum = 100
            connectProperties.maximumPacketSize = 500
            mqtt.username = ""
            mqtt.password = ""
            if usingTLS {
                mqtt.enableSSL = true
                mqtt.allowUntrustCACertificate = true
            }
            mqtt.connectProperties = connectProperties
            
            mqtt.keepAlive = 30
            
            mqtt.autoReconnect = true
            
            mqtt.didSubscribeTopics = { mqtt, dict, topics, ack in
                print("did sub \(dict)")
                self.connectedToMQTTServer = .subscribe
                Task {
                    await self.generateQRCode()
                }
                self.publishTimer?.invalidate()
                self.publishTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { timer in
                    Task {
                        await self.publishData()
                    }
                })
            }
            
            mqtt.didConnectAck = { mqtt, reason, ack in
                self.connectedToMQTTServer = .connected
                guard !self.publishTopic.isEmpty else { return }
                mqtt.subscribe([MqttSubscription(topic: "\(self.publishTopic)/inverse")])
            }
            
            mqtt.didDisconnect = { mqtt, error in
                self.connectedToMQTTServer = .disconnected
            }
            
            mqtt.didReceiveMessage = { mqtt, message, id, publish in
                guard let project = Resolve.shared.wrappedProject else { return }
                guard let message = String(data: Data(message.payload), encoding: .utf8)?.decrypt() else { return }
                
                if message.starts(with: "req@"), let jobId = message.split(separator: "@").last {
                    guard let getProjectListFunc = project.checking[dynamicMember: "GetRenderJobList"],
                          let jobList = try? getProjectListFunc.throwing.dynamicallyCall(withArguments: [])
                    else {
                        return
                    }
                    guard let requestJob = jobList.filter({ String($0["JobId"]) ?? "" == jobId }).first else { return }
                    
                    let details = JobDetails(
                        jobId: String(String(requestJob["JobId"])?.suffix(4) ?? ""),
                        targetDir: String(requestJob["TargetDir"])?.shorten(maxLength: 50) ?? "",
                        isExportVideo: Bool(requestJob["IsExportVideo"]) ?? false,
                        isExportAudio: Bool(requestJob["IsExportAudio"]) ?? false,
                        formatWidth: Int(requestJob["FormatWidth"]) ?? 0,
                        formatHeight: Int(requestJob["FormatHeight"]) ?? 0,
                        frameRate: String(requestJob["FrameRate"]) ?? "",
                        pixelAspectRatio: CGFloat(Float(requestJob["PixelAspectRatio"]) ?? 0),
                        audioBitDepth: Int(requestJob["AudioBitDepth"]) ?? 0,
                        audioSampleRate: Int(requestJob["AudioSampleRate"]) ?? 0,
                        exportAlpha: Bool(requestJob["ExportAlpha"]) ?? false,
                        outputFileName: String(requestJob["OutputFilename"])?.shorten(maxLength: 28) ?? "",
                        renderMode: String(requestJob["RenderMode"])?.shorten(maxLength: 28) ?? "",
                        presetName: String(requestJob["PresetName"])?.shorten(maxLength: 28) ?? "",
                        videoFormat: String(requestJob["VideoFormat"])?.shorten(maxLength: 28) ?? "",
                        videoCodec: String(requestJob["VideoCodec"])?.shorten(maxLength: 28) ?? "",
                        audioCodec: String(requestJob["AudioCodec"])?.shorten(maxLength: 28) ?? ""
                    )
                    
                    guard let data = try? JSONEncoder().encode(details),
                          let dataStr = String(data: data, encoding: .utf8)
                    else { return }
                    
                    let publishProperties = MqttPublishProperties()
                    publishProperties.contentType = "String"
                    _ = mqtt.publish(self.publishTopic, withString: dataStr.encrypt(), properties: publishProperties)
                    
                } else if message.starts(with: "dtk@"), let deviceToken = message.split(separator: "@").last  {
                    let result = self.deviceTokens.insert(String(deviceToken))
                    guard result.inserted else { return }
                    APNSServer.shared.sendConnectionBuildNotification(deviceToken: String(deviceToken))
                } else if message.starts(with: "atk@"), let activityToken = message.split(separator: "@").last {
                    let result = self.activityTokens.insert(String(activityToken))
                    guard result.inserted else { return }
                    self.lastActivityInfo.updateValue(nil, forKey: String(activityToken))
                } else if message.starts(with: "rma@"), let activityToken = message.split(separator: "@").last {
                    self.activityTokens.remove(String(activityToken))
                    self.lastActivityInfo.removeValue(forKey: String(activityToken))
                } else if message.starts(with: "env@"), let env = message.split(separator: "@").last {
                    if env == "debug" {
                        APNSServer.shared.isDebugEnv = true
                    } else if env == "release" {
                        APNSServer.shared.isDebugEnv = false
                    }
                } else if let job = try? JSONDecoder().decode(StartJob.self, from: message.data(using: .utf8) ?? Data()) {
                    guard abs(job.date.timeIntervalSinceNow) < 30
                    else {
                        print("RenderJob Out of Date")
                        return
                    }
                    print("Start render \(job.jobId)")
                    guard let project = Resolve.shared.wrappedProject,
                          let isRenderingFunc = project.checking[dynamicMember: "IsRenderingInProgress"],
                          let isRenderingObj = try? isRenderingFunc.throwing.dynamicallyCall(withArguments: []),
                          let isRendering = Bool(isRenderingObj),
                          !isRendering
                    else { return }
                    
                    guard let startRenderFunc = project.checking[dynamicMember: "StartRendering"],
                          let _ = try? startRenderFunc.throwing.dynamicallyCall(withArguments: [[String(job.jobId)], false])
                    else {
                        print("Can not render!")
                        return
                    }
                }
                
            }
            
            _ = mqtt.connect()
            
            
        }
        
        func publishData() {
//            print("s0")
            guard let mqtt = mqtt,
                  mqtt.connState == .connected,
                  let project = Resolve.shared.wrappedProject
            else {
                self.publishTimer?.invalidate()
                return
            }
//            print("s1")
            guard let getIdFunc = project.checking[dynamicMember: "GetUniqueId"],
                  let idObj = try? getIdFunc.throwing.dynamicallyCall(withArguments: []),
                  let id = String(idObj),
                  id == self.projectId
            else {
                print("Project Changed.")
                mqtt.unsubscribe(publishTopic)
                publishTimer?.invalidate()
                Task {
                    await tryToGetProject(loop: true)
                }
                return
            }
//            print("s2")
            
            guard let getRenderJobListFunc = project.checking[dynamicMember: "GetRenderJobList"],
                  let renderJobs = try? getRenderJobListFunc.throwing.dynamicallyCall(withArguments: []),
                  renderJobs != Resolve.shared.noneObject
            else { return }
//            print("s3")
            
            var renderJobList: [JobBasicInfo] = []
            
            for (index, job) in renderJobs.enumerated() {
//                print("p-1")
                guard job != Resolve.shared.noneObject else { return }
//                print("p-0")
                let jobId = String(job["JobId"]) ?? "Unknown Job Id"
                let jobName = String(job["RenderJobName"]) ?? "Unknown Job Name"
                let timelineName = String(job["TimelineName"]) ?? "Unknown Timeline Name"
                
//                print("p0")
                guard let getRenderJobStatusFunc = project.checking[dynamicMember: "GetRenderJobStatus"],
                      let status = try? getRenderJobStatusFunc.throwing.dynamicallyCall(withArguments: [jobId]),
                      status != Resolve.shared.noneObject
                else { return }
//                print("p1")
                let jobStatus = JobStatus(from: String(status["JobStatus"]) ?? "")
//                print("p2")
                let jobProgress = Int(status["CompletionPercentage"]) ?? 0
                var estimatedTime = 0
                if status.contains("EstimatedTimeRemainingInMs") {
                    estimatedTime = Int(status["EstimatedTimeRemainingInMs"]) ?? 0
                }
                
                var timeTaken = 0
                if status.contains("TimeTakenToRenderInMs") {
                    timeTaken = Int(status["TimeTakenToRenderInMs"]) ?? 0
                }
                
                let jobBasicInfo = JobBasicInfo(jobId: jobId, jobName: jobName, timelineName: timelineName, jobStatus: jobStatus, jobProgress: jobProgress, estimatedTime: estimatedTime, timeTaken: timeTaken, order: index)
                renderJobList.append(jobBasicInfo)
                
                renderJobsSelectionList.updateValue(RenderJobSelectionInfo(jobID: jobId, jobName: jobName, timelineName: timelineName, status: jobStatus, order: index), forKey: jobId)
                
                guard let data = try? JSONEncoder().encode(jobBasicInfo),
                      let dataStr = String(data: data, encoding: .utf8)
                else { continue }
                
                let publishProperties = MqttPublishProperties()
                publishProperties.contentType = "String"
                mqtt.publish(self.publishTopic, withString: dataStr.encrypt(), properties: publishProperties)
            }
            
            // Remove jobs have been deleted
            for job in renderJobList {
                lastRenderJobList?.removeAll(where: { $0.jobId == job.jobId })
            }
            for job in lastRenderJobList ?? [] {
                // These jobs is deleted
                let removeJob = RemoveJobInfo(removedJobId: job.jobId)
                guard let data = try? JSONEncoder().encode(removeJob),
                      let dataStr = String(data: data, encoding: .utf8)
                else { continue }
                
                let publishProperties = MqttPublishProperties()
                publishProperties.contentType = "String"
                mqtt.publish(self.publishTopic, withString: dataStr.encrypt(), properties: publishProperties)
                
                //remove job from Start Render List too
                renderJobsSelectionList.removeValue(forKey: removeJob.removedJobId)
            }
            lastRenderJobList = renderJobList
            
            let readyJobCount = renderJobList.filter({ $0.jobStatus == .ready }).count
            let renderingJob = renderJobList.filter({ $0.jobStatus == .rendering }).first ?? renderJobList.last
            let currentJobId = renderingJob?.jobId ?? ""
            var finishJobCount = renderJobList.filter({ $0.jobStatus == .finish }).count
            let failedJobCount = renderJobList.filter({ $0.jobStatus == .failed || $0.jobStatus == .canceled }).count
//            print("t0")
            guard let isRenderingFunc = project.checking[dynamicMember: "IsRenderingInProgress"],
                  let isRenderingObj = try? isRenderingFunc.throwing.dynamicallyCall(withArguments: []),
                  let isRendering = Bool(isRenderingObj)
            else { return }
            
//            print("t1")
            renderJobsButtonDisabled = isRendering
            if isRendering {
                finishJobCount += 1
            }
            
            // Send Live Activity and Notifications
            let info = ProjectInfoToWidget(readyJobNumber: readyJobCount, failedJobNumber: failedJobCount, finishJobNumber: finishJobCount, isRendering: isRendering, lastUpdate: Date(), currentJobId: currentJobId, currentJobName: renderingJob?.jobName ?? "No Current Job", currentTimelineName: renderingJob?.timelineName ?? "No Current Timeline", currentJobStatus: renderingJob?.jobStatus ?? .unknown, currentJobProgress: renderingJob?.jobProgress ?? 0, currentJobDurationString: renderingJob?.formatedJobDuration(rendering: isRendering) ?? "Unknown")
            guard let encodedInfo = try? JSONEncoder().encode(info),
                  let encodedString = String(data: encodedInfo, encoding: .utf8)
            else {
                return
            }
            
            for activityToken in activityTokens {
                if lastActivityInfo[activityToken] == nil {
                    APNSServer.shared.sendLiveActivityUpdateNotification(activityToken: activityToken, infoString: encodedString, alert: NotificationAlert(title: "已订阅实时活动通知", subTitle: nil, body: "任务状态将显示在实时活动中。"))
                    print("实时活动：订阅通知")
                } else if isRendering != lastIsRendering {
                    if isRendering == true {
                            APNSServer.shared.sendLiveActivityUpdateNotification(activityToken: activityToken, infoString: encodedString, alert: NotificationAlert(title: "开始渲染", subTitle: nil, body: "任务队列已开始渲染，您将在队列停止时收到通知。"))
                            print("实时活动：开始渲染")
                    } else if failedJobCount > 0 {
                            APNSServer.shared.sendLiveActivityEndNotification(activityToken: activityToken, infoString: encodedString)
                            print("实时活动：渲染中止")
                    } else {
                            APNSServer.shared.sendLiveActivityEndNotification(activityToken: activityToken, infoString: encodedString)
                            print("实时活动：渲染完成")
                    }
                } else if lastActivityInfo[activityToken] != info {
                        APNSServer.shared.sendLiveActivityUpdateNotification(activityToken: activityToken, infoString: encodedString, alert: nil)
                        print("实时活动：状态更新")
                }
                lastActivityInfo.updateValue(info, forKey: activityToken)
            }
            
            if isRendering != lastIsRendering {
                for deviceToken in deviceTokens {
                    if isRendering {
                        APNSServer.shared.sendEndOfRenderNotification(deviceToken: deviceToken, alert: NotificationAlert(title: "\(projectName)渲染开始", subTitle: nil, body: "请留意实时活动、任务通知。点击查看详情。"))
                        print("已发送开始渲染通知")
                    } else {
                        if failedJobCount > 0 {
                            APNSServer.shared.sendEndOfRenderNotification(deviceToken: deviceToken, alert: NotificationAlert(title: "\(projectName)渲染停止", subTitle: nil, body: "渲染任务已停止，\(failedJobCount)个任务未渲染，点击查看详情。"))
                            print("已发送渲染中止通知")
                        } else {
                            APNSServer.shared.sendEndOfRenderNotification(deviceToken: deviceToken, alert: NotificationAlert(title: "\(projectName)渲染完成", subTitle: nil, body: "渲染任务已完成，点击查看详情。"))
                            print("已发送渲染完成通知")
                        }
                    }
                }
            }
            
            lastIsRendering = isRendering
        }
        
        func generateQRCode() async {
            guard !projectName.isEmpty, !publishTopic.isEmpty else { return }
            guard let host = mqtt?.host, let port = mqtt?.port else { return }
            
            let info = ProjectQRCodeInfo(projectName: projectName, brokerAddress: host, brokerPort: port, topicAddress: publishTopic, privateKey: TransmitEncryption.privateKey)
            let encoder = JSONEncoder()
            guard let data = try? encoder.encode(info) else { return }
            
            if let filter = CIFilter(name: "CIQRCodeGenerator") {
                filter.setValue(data, forKey: "inputMessage")
                let transform = CGAffineTransform(scaleX: 10, y: 10)
                
                if let output = filter.outputImage?.transformed(by: transform) {
                    await MainActor.run {
                        let cgImage = CIContext().createCGImage(output, from: output.extent)
                        withAnimation {
                            self.qrCodeImage = cgImage
                        }
                    }
                }
            }
        }
        
        func getDeviceTokenString() -> String {
            if deviceTokens.isEmpty {
                return "请在APP中添加并打开项目..."
            } else if deviceTokens.count == 1 {
                guard let token = deviceTokens.first, token.count > 8 else { return "密钥不正确" }
                return "\(token.prefix(4))****\(token.suffix(4))"
            } else {
                guard let token = deviceTokens.first, token.count > 8 else { return "密钥不正确" }
                return "\(token.prefix(4))****\(token.suffix(4)) 等\(deviceTokens.count)台设备"
            }
        }
        
        func getActivityTokenString() -> String {
            if activityTokens.isEmpty {
                return "请在APP的项目里订阅通知..."
            } else if activityTokens.count == 1 {
                guard let token = activityTokens.first, token.count > 8 else { return "密钥不正确" }
                return "\(token.prefix(4))****\(token.suffix(4))"
            } else {
                guard let token = activityTokens.first, token.count > 8 else { return "密钥不正确" }
                return "\(token.prefix(4))****\(token.suffix(4)) 等\(activityTokens.count)台设备"
            }
        }
        
        func startRenderJobs(jobIds: [String]) {
            guard let project = Resolve.shared.wrappedProject else { return }
            
            guard let isRenderingFunc = project.checking[dynamicMember: "IsRenderingInProgress"],
                  let isRenderingObj = try? isRenderingFunc.throwing.dynamicallyCall(withArguments: []),
                  let isRendering = Bool(isRenderingObj)
            else { return }
            
            guard !isRendering else { return }
            guard !jobIds.isEmpty,
                  let startRenderFunc = project.checking[dynamicMember: "StartRendering"],
                  let _ = try? startRenderFunc.throwing.dynamicallyCall(withArguments: [jobIds, false])
            else {
                print("Can not render!")
                return
            }
            print("Start render \(jobIds)")
        }
        
    }
    
}

fileprivate extension String {
    func shorten(maxLength: Int) -> String {
        guard self.count > maxLength else {
            return self
        }
        let suffix = self.suffix(maxLength - 4)
        return "... \(suffix)"
    }
    
    func hideMiddle() -> String {
        guard self.count > 12 else {
            return self
        }
        return "\(self.prefix(4))....\(self.suffix(4))"
    }
}
