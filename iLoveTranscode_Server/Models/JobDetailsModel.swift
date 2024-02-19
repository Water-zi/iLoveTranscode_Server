//
//  JobDetailsModel.swift
//  iLoveTranscode
//
//  Created by 唐梓皓 on 2024/2/1.
//

import Foundation

struct JobDetails: Codable {
    var jobId: String
    var targetDir: String
    var isExportVideo: Bool
    var isExportAudio: Bool
    var formatWidth: Int
    var formatHeight: Int
    var frameRate: String
    var pixelAspectRatio: CGFloat
    var audioBitDepth: Int
    var audioSampleRate: Int
    var exportAlpha: Bool
    var outputFileName: String
    var renderMode: String
    var presetName: String
    var videoFormat: String
    var videoCodec: String
    var audioCodec: String
    
    enum CodingKeys: String, CodingKey {
        case jobId = "id"
        case targetDir = "td"
        case isExportVideo = "v"
        case isExportAudio = "a"
        case formatWidth = "w"
        case formatHeight = "h"
        case frameRate = "fr"
        case pixelAspectRatio = "pa"
        case audioBitDepth = "abd"
        case audioSampleRate = "asr"
        case exportAlpha = "ea"
        case outputFileName = "ofn"
        case renderMode = "rm"
        case presetName = "pn"
        case videoFormat = "vf"
        case videoCodec = "vc"
        case audioCodec = "ac"
    }
}
