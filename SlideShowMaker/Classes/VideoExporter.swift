//
//  VideoMaker.swift
//  SlideShowMaker
//
//  Created by lcf on 26/07/2017.
//  Copyright © 2017 flow. All rights reserved.
//

import UIKit
import AVFoundation

public struct VideoItem {
    
    var video: AVURLAsset!
    var audio: AVURLAsset?
    var audioTimeRange: CMTimeRange?
}

public class VideoExporter: NSObject {

    /// Callback
    typealias ExportingBlock = ((_ completed: Bool, _ progress: Float?, _ url: URL?, _ error: Error? ) -> Void)
    
    var exportingBlock: ExportingBlock?
    var videoItem: VideoItem?
    
    var mixComposition = AVMutableComposition()
    
    fileprivate let videoTrackID = CMPersistentTrackID(1)
    fileprivate let audioTrackID = CMPersistentTrackID(2)
    fileprivate var exporter: AVAssetExportSession?
    
    override init() {
        super.init()
    }
    convenience init(withe item: VideoItem) {
        self.init()
        self.videoItem = item
    }
    
    public func export() {
        guard let item = self.videoItem else {
            self.exportingBlock?(false, 0, nil, NSError(domain: "video item is empty", code: 0, userInfo: nil))
            return
        }
        
        self.mixComposition = AVMutableComposition()
        self.addTrack(item: item, composition: self.mixComposition)
        let videoCompositionTrack = self.mixComposition.track(withTrackID: videoTrackID)!
        
        let timeRange = CMTimeRange(start: CMTime.zero, duration: item.video.duration)
        
        self.insert(
            item: item,
            videoCompositionTrack: videoCompositionTrack,
            timeRange: timeRange
        )
        
        if item.audio != nil {
            if let audioCompositionTrack = self.mixComposition.track(withTrackID: audioTrackID) {
                self.addMusic(item: item, audioCompositionTrack: audioCompositionTrack)
            }
        }
        self.merge(composition: self.mixComposition, duration: timeRange.duration)
    }
    
    public func cancelExport() {
        if self.isExporting() {
            self.exporter?.cancelExport()
        }
    }
    
    public func isExporting() -> Bool {
        if self.exporter != nil {
            return self.exporter!.status == .exporting
        }
        return false
    }
}

// MARK: - Edit
extension VideoExporter {
    
    /// Add video and audio composition track
    fileprivate func addTrack(item: VideoItem, composition: AVMutableComposition) {
        let _ = composition.addMutableTrack(withMediaType: .video, preferredTrackID: videoTrackID)
        if item.audio != nil {
            let _ = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: audioTrackID)
        }
    }
    
    /// Add video to composition
    fileprivate func insert(item: VideoItem, videoCompositionTrack: AVMutableCompositionTrack, timeRange: CMTimeRange) {
        guard let videoTrack = item.video.tracks(withMediaType: .video).first else { return }
        
        try? videoCompositionTrack.insertTimeRange(timeRange, of: videoTrack, at: CMTime.zero)
    }
    
    /// Add music
    fileprivate func addMusic(item: VideoItem, audioCompositionTrack: AVMutableCompositionTrack) {
        guard let audio = item.audio else { return }
        
        let audioStart = item.audioTimeRange != nil ? item.audioTimeRange!.start : CMTime.zero
        let audioDuration = item.audioTimeRange != nil ? item.audioTimeRange!.duration : audio.duration
        let audioTimescale = audio.duration.timescale
        let videoDuratin = item.video.duration
        
        // video is lengther than audio
        if videoDuratin.seconds > audioDuration.seconds {
            let repeatCount = Int(videoDuratin.seconds / audioDuration.seconds)
            let remain = videoDuratin.seconds.truncatingRemainder(dividingBy: audioDuration.seconds)
            let timeRange = CMTimeRange(start: audioStart, duration: audioDuration)
            
            for i in 0..<repeatCount {
                let start = CMTime(seconds: Double(i) * audioDuration.seconds, preferredTimescale: audioTimescale)
                
                self.addAudio(audio: audio, start: start, timeRage: timeRange, audioCompositionTrack: audioCompositionTrack)
            }
            
            if remain > 0 {
                let startSeconds = Double(repeatCount) * audioDuration.seconds
                let start = CMTime(seconds: startSeconds, preferredTimescale: audioTimescale)
                let remainDuration = CMTime(seconds: remain, preferredTimescale: audioTimescale)
                let remainTimeRange = CMTimeRange(start: audioStart, duration: remainDuration)
                
                print(startSeconds, start, remainDuration, remainTimeRange)
                self.addAudio(audio: audio, start: start, timeRage: remainTimeRange, audioCompositionTrack: audioCompositionTrack)
                
            }
        } else {
            let timeRange = CMTimeRange(start: audioStart, duration: videoDuratin)
            self.addAudio(audio: audio, start: CMTime.zero, timeRage: timeRange, audioCompositionTrack: audioCompositionTrack)
        }
    }
    
    fileprivate func addAudio(audio: AVURLAsset, start: CMTime, timeRage: CMTimeRange, audioCompositionTrack: AVMutableCompositionTrack) {
        if let track = audio.tracks(withMediaType: .audio).first {
            try? audioCompositionTrack.insertTimeRange(timeRage, of: track, at: start)
        }
    }
    
    fileprivate func merge(composition: AVMutableComposition, duration: CMTime) {
        
        let filename = "merge.mov"
        let path = K.Path.MovURL.appendingPathComponent(filename)
        print(path)
        self.deletePreviousTmpVideo(url: path)
        
        self.exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality)
        if let exporter = self.exporter {
            exporter.outputURL = path
            exporter.outputFileType = .mov
            exporter.shouldOptimizeForNetworkUse = true
            exporter.timeRange = CMTimeRange(start: CMTime.zero, duration: duration)
            
            let timer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.readProgress), userInfo: nil, repeats: true)
            
            exporter.exportAsynchronously {
                
                timer.invalidate()
                
                if exporter.status == AVAssetExportSession.Status.failed {
                    print(#function, exporter.error ?? "unknow error")
                    self.exportingBlock?(false, nil, nil, exporter.error)
                } else {
                    self.exportingBlock?(true, 1.0, path, nil)
                }
                print("export completed")
            }
        }
    }
}

// MARK: - Private
extension VideoExporter {
    
    fileprivate func deletePreviousTmpVideo(url: URL) {
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
    }
    
    @objc fileprivate func readProgress() {
        if let exporter = self.exporter {
            print(#function, exporter.progress)
            exportingBlock?(false, exporter.progress, nil, nil)
        }
    }
}
