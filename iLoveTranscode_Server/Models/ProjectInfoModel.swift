//
//  ProjectInfoModel.swift
//  iLoveTranscode
//
//  Created by 唐梓皓 on 2024/2/1.
//

import Foundation

struct ProjectInfoFromMQTT: Codable {
    var id: UUID = UUID()
    
    var readyJobNumber: Int
    var failedJobNumber: Int
    var finishJobNumber: Int
    var currentJobId: String
    var isRendering: Bool
    
    enum CodingKeys: String, CodingKey {
        case readyJobNumber = "rjn"
        case failedJobNumber = "fjn"
        case finishJobNumber = "fnjn"
        case currentJobId = "cj"
        case isRendering = "ir"
    }
}

struct ProjectInfoToWidget: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    
    var readyJobNumber: Int
    var failedJobNumber: Int
    var finishJobNumber: Int
    var isRendering: Bool
    
    var lastUpdate: Date
    
    var currentJobId: String
    var currentJobName: String
    var currentTimelineName: String
    var currentJobStatus: JobStatus
    var currentJobProgress: Int
    var currentJobDurationString: String
}

extension ProjectInfoToWidget: Equatable {
    static func == (lhs: ProjectInfoToWidget, rhs: ProjectInfoToWidget) -> Bool {
        return lhs.readyJobNumber == rhs.readyJobNumber &&
            lhs.failedJobNumber == rhs.failedJobNumber &&
            lhs.finishJobNumber == rhs.finishJobNumber &&
            lhs.isRendering == rhs.isRendering &&
            lhs.currentJobId == rhs.currentJobId &&
            lhs.currentJobName == rhs.currentJobName &&
            lhs.currentTimelineName == rhs.currentTimelineName &&
            lhs.currentJobStatus == rhs.currentJobStatus &&
            lhs.currentJobProgress == rhs.currentJobProgress &&
            lhs.currentJobDurationString == rhs.currentJobDurationString
    }
}
