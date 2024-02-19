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
    var selected: Bool
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
        @Published var showDaVinciResolveNotInstalledSheet: Bool = false
        
        private var publishTopic: String = ""
        
        @Published var qrCodeImage: CGImage?
        
        private var publishTimer: Timer?
        
        //        @Published var lastCommand: String = "Latest Command Will be Display Here."
        @Published var deviceToken: String?
        @Published var activityToken: String?
        private var lastActivityInfo: ProjectInfoToWidget?
        @Published private(set) var lastIsRendering: Bool = false
        
        @Published var renderJobsSelectionList: [String : RenderJobSelectionInfo] = [:]
        @Published var showStartRenderSelectionListView: Bool = false
        @Published var renderJobsButtonDisabled: Bool = false
        
        func tryToGetProject(loop: Bool) async {
            guard Resolve.shared.davinciInstalled,
                  let dvr = Resolve.shared.sys?.modules["fusionscript"].scriptapp("Resolve"),
                  let projectManager = dvr.callFunction(name: "GetProjectManager", withArguments: []),
                  let currentProject = projectManager.callFunction(name: "GetCurrentProject", withArguments: []),
                  let name = currentProject.callFunction(name: "GetName", withArguments: []),
                  let id = currentProject.callFunction(name: "GetUniqueId", withArguments: [])
            else {
                guard Resolve.shared.davinciInstalled
                else {
                    showDaVinciResolveNotInstalledSheet = true
                    return
                }
                projectName = ""
                qrCodeImage = nil
                mqtt?.disconnect()
                print("DVR, PM and Project Not Found")
                await MainActor.run {
                    self.canRetryGetProject = true
                }
                guard loop else { return }
                print("Will retry in 1s")
                Task {
                    try? await Task.sleep(for: .seconds(1))
                    await tryToGetProject(loop: true)
                }
                return
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
                    let jobList = project.GetRenderJobList()
                    guard let requestJob = jobList.filter({ String($0["JobId"]) ?? "" == jobId }).first else { return }
                    
                    let details = JobDetails(
                        jobId: String(String(requestJob["JobId"])?.suffix(4) ?? ""),
                        targetDir: String(requestJob["TargetDir"])?.shorten(maxLength: 60) ?? "",
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
                    self.deviceToken = String(deviceToken)
                    APNSServer.shared.sendConnectionBuildNotification(deviceToken: String(deviceToken))
                } else if message.starts(with: "atk@"), let activityToken = message.split(separator: "@").last {
                    guard (self.activityToken ?? "") != activityToken else { return }
                    self.activityToken = String(activityToken)
                    self.lastActivityInfo = nil
                }
                
            }
            
            _ = mqtt.connect()
            
            
        }
        
        func publishData() {
            guard let mqtt = mqtt,
                  mqtt.connState == .connected,
                  let project = Resolve.shared.wrappedProject
            else {
                self.publishTimer?.invalidate()
                return
            }
            guard let idPO = project.callFunction(name: "GetUniqueId", withArguments: []),
                  let id = String(idPO),
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
            
            guard let renderJobs = project.callFunction(name: "GetRenderJobList", withArguments: []) else { return }
            
            var renderJobList: [JobBasicInfo] = []
            
            for (index, job) in renderJobs.enumerated() {
                let jobId = String(job["JobId"]) ?? "Unknown Job Id"
                let jobName = String(job["RenderJobName"]) ?? "Unknown Job Name"
                let timelineName = String(job["TimelineName"]) ?? "Unknown Timeline Name"
                
                
                guard let status = project.callFunction(name: "GetRenderJobStatus", withArguments: [jobId]) else { return }
                
                let jobStatus = JobStatus(from: String(status["JobStatus"]) ?? "")
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
                
                let job = renderJobsSelectionList[jobId]
                renderJobsSelectionList.updateValue(RenderJobSelectionInfo(jobID: jobId, jobName: jobName, timelineName: timelineName, status: jobStatus, order: index, selected: (job?.selected ?? (jobStatus == .ready))), forKey: jobId)
                
                guard let data = try? JSONEncoder().encode(jobBasicInfo),
                      let dataStr = String(data: data, encoding: .utf8)
                else { continue }
                
                let publishProperties = MqttPublishProperties()
                publishProperties.contentType = "String"
                mqtt.publish(self.publishTopic, withString: dataStr.encrypt(), properties: publishProperties)
            }
            
            let readyJobCount = renderJobList.filter({ $0.jobStatus == .ready }).count
            let renderingJob = renderJobList.filter({ $0.jobStatus == .rendering }).first ?? renderJobList.last
            let currentJobId = renderingJob?.jobId ?? ""
            var finishJobCount = renderJobList.filter({ $0.jobStatus == .finish }).count
            let failedJobCount = renderJobList.filter({ $0.jobStatus == .failed || $0.jobStatus == .canceled }).count
            
            let isRendering: Bool = Bool(project.callFunction(name: "IsRenderingInProgress", withArguments: []) ?? false) ?? false
            renderJobsButtonDisabled = isRendering
            if isRendering {
                finishJobCount += 1
            }
            
            // Send Live Activity and Notifications
            let info = ProjectInfoToWidget(readyJobNumber: readyJobCount, failedJobNumber: failedJobCount, finishJobNumber: finishJobCount, isRendering: isRendering, lastUpdate: Date(), currentJobId: currentJobId, currentJobName: renderingJob?.jobName ?? "No Current Job", currentTimelineName: renderingJob?.timelineName ?? "No Current Timeline", currentJobStatus: renderingJob?.jobStatus ?? .unknown, currentJobProgress: renderingJob?.jobProgress ?? 0, currentJobDurationString: renderingJob?.formatedJobDuration(rendering: isRendering) ?? "Unknown")
            if lastActivityInfo != info,
               let encodedInfo = try? JSONEncoder().encode(info),
               let encodedString = String(data: encodedInfo, encoding: .utf8) {
                if lastActivityInfo == nil {
                    if let activityToken = activityToken {APNSServer.shared.sendLiveActivityUpdateNotification(activityToken: activityToken, infoString: encodedString, alert: NotificationAlert(title: "已订阅实时活动通知", subTitle: nil, body: "任务状态将显示在实时活动中。"))
                        lastActivityInfo = info
                        print("实时活动：订阅通知")
                    }
                } else if isRendering != lastIsRendering {
                    if isRendering == true {
                        if let activityToken = activityToken {
                            APNSServer.shared.sendLiveActivityUpdateNotification(activityToken: activityToken, infoString: encodedString, alert: NotificationAlert(title: "开始渲染", subTitle: nil, body: "任务队列已开始渲染，您将在队列停止时收到通知。"))
                            lastActivityInfo = info
                            print("实时活动：开始渲染")
                        }
                    } else if failedJobCount > 0 {
                        if let activityToken = activityToken {
                            APNSServer.shared.sendLiveActivityEndNotification(activityToken: activityToken, infoString: encodedString)
                            lastActivityInfo = info
                            print("实时活动：渲染中止")
                        }
                        if UserDefaults.standard.bool(forKey: "PushNotificationAnyway"), let deviceToken = deviceToken {
                            APNSServer.shared.sendEndOfRenderNotification(deviceToken: deviceToken, alert: NotificationAlert(title: "\(projectName)渲染停止", subTitle: nil, body: "渲染任务已停止，\(failedJobCount)个任务未渲染，点击查看详情。"))
                            print("已发送渲染中止通知")
                        }
                    } else {
                        if let activityToken = activityToken {
                            APNSServer.shared.sendLiveActivityEndNotification(activityToken: activityToken, infoString: encodedString)
                            lastActivityInfo = info
                            print("实时活动：渲染完成")
                        }
                        if UserDefaults.standard.bool(forKey: "PushNotificationAnyway"), let deviceToken = deviceToken {
                            APNSServer.shared.sendEndOfRenderNotification(deviceToken: deviceToken, alert: NotificationAlert(title: "\(projectName)渲染完成", subTitle: nil, body: "渲染任务已完成，点击查看详情。"))
                            print("已发送渲染完成通知")
                        }
                    }
                } else {
                    if let activityToken = activityToken {
                        APNSServer.shared.sendLiveActivityUpdateNotification(activityToken: activityToken, infoString: encodedString, alert: nil)
                        lastActivityInfo = info
                        print("实时活动：状态更新")
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
            guard let token = deviceToken, token.count > 8 else { return "密钥不正确" }
            return "\(token.prefix(4))****\(token.suffix(4))"
        }
        
        func getActivityTokenString() -> String {
            guard let token = activityToken, token.count > 8 else { return "密钥不正确" }
            return "\(token.prefix(4))****\(token.suffix(4))"
        }
        
        func toggleRenderJobSelection(for job: RenderJobSelectionInfo) {
            renderJobsSelectionList[job.jobID]?.selected.toggle()
        }
        
        func startRenderJobs() {
            guard let project = Resolve.shared.wrappedProject else { return }
            let isRendering: Bool = Bool(project.callFunction(name: "IsRenderingInProgress", withArguments: []) ?? false) ?? false
            guard !isRendering else { return }
            let jobIds = renderJobsSelectionList.values.filter({ $0.selected }).sorted(by: { $0.order < $1.order }).compactMap({ $0.jobID })
            guard !jobIds.isEmpty,
                  let startRenderFunc = project.checking[dynamicMember: "StartRendering"],
                  let _ = try? startRenderFunc.throwing.dynamicallyCall(withArguments: [jobIds, false])
            else {
                print("Can not render!")
                showStartRenderSelectionListView = false
                return
            }
            print("Start render \(jobIds)")
            showStartRenderSelectionListView = false
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
