//
//  JobBasicInfoModel.swift
//  iLoveTranscode
//
//  Created by 唐梓皓 on 2024/1/31.
//

import SwiftUI
import Foundation

struct JobBasicInfo: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    
    var jobId: String
    var jobName: String
    var timelineName: String
    var jobStatus: JobStatus
    var jobProgress: Int
    var estimatedTime: Int
    var timeTaken: Int
    var order: Int
    
    var lastUpdate: Date?
    
    enum CodingKeys: String, CodingKey {
        case jobId = "id"
        case jobName = "jn"
        case timelineName = "tn"
        case jobStatus = "js"
        case jobProgress = "jp"
        case estimatedTime = "et"
        case timeTaken = "tt"
        case order = "od"
    }
    
    func formatedJobDuration(rendering: Bool) -> String {
        var duration = 0
        if jobStatus == .rendering {
            duration = estimatedTime
        } else {
            duration = timeTaken
        }
        let totalSeconds = duration / 1000
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%01dh%01dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%01dm%01ds", minutes, seconds)
        } else if seconds > 0 {
            return String(format: "%01ds", seconds)
        } else {
            if rendering {
                return "计算中"
            } else {
                return "待机"
            }
        }
    }
    
    func intervalSinceLastUpdate() -> String {
        guard let date = self.lastUpdate else { return "Unknown" }
        let currentDate = Date()
        let timeInterval = Int(currentDate.timeIntervalSince(date))

        if timeInterval < 10 {
            return "刚刚"
        } else if timeInterval < 60 {
            return String(format: "%01ds", timeInterval)
        } else if timeInterval < 3600 {
            let minutes = timeInterval / 60
            let seconds = timeInterval % 60
            return String(format: "%01dm%01ds", minutes, seconds)
        } else {
            let hours = timeInterval / 3600
            let minutes = (timeInterval % 3600) / 60
            let seconds = timeInterval % 60
            return String(format: "%01dh%01dm%01ds", hours, minutes, seconds)
        }
    }
}

enum JobStatus: Int, Codable {
    case ready, rendering, canceled, failed, finish, unknown
    
    init(from str: String) {
        switch str {
        case "就绪", "Ready":
            self = .ready
        case "渲染", "Rendering":
            self = .rendering
        case "已取消", "Cancelled":
            self = .canceled
        case "失败", "Failed":
            self = .failed
        case "完成", "Complete":
            self = .finish
        default:
            self = .unknown
        } 
    }
    
    var string: String {
        switch self {
        case .ready:
            return "已就绪"
        case .rendering:
            return "渲染中"
        case .canceled:
            return "已取消"
        case .failed:
            return "已失败"
        case .finish:
            return "已完成"
        case .unknown:
            return "未知状态"
        }
    }
    
    var color: Color {
        switch self {
        case .ready:
            return Color.blue
        case .rendering:
            return Color.green
        case .canceled:
            return Color.red
        case .failed:
            return Color.red
        case .finish:
            return Color.gray
        case .unknown:
            return Color.orange
        }
    }
}
