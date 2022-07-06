//
//  VideoMaker.swift
//  SlideShowMaker
//
//  Created by lcf on 27/07/2017.
//  Copyright © 2017 flow. All rights reserved.
//

import UIKit
import AVFoundation

public class VideoMaker: NSObject {
    
    public typealias CompletedCombineBlock = (_ success: Bool, _ videoURL: URL?) -> Void
    public typealias Progress = (_ progress: Float) -> Void

    public var images: [UIImage?] = []
    public var transition: ImageTransition = .none
    public var movement: ImageMovement = .none
    public var movementFade: MovementFade = .upLeft
    public var contentMode = UIView.ContentMode.scaleAspectFit
    
    public var progress: Progress?
    
    public var quarity = CGInterpolationQuality.low
    
    // Video resolution
    public var size = CGSize(width: 640, height: 640)
    
    public var definition: CGFloat = 1
    
    /// Video duration
    public var videoDuration: Int?
    
    /// Every image duration, defualt 2
    public var frameDuration: Int = 2
    
    // Every image animation duration, default 1
    public var transitionDuration: Int = 1
    
    public var transitionFrameCount = 60
    public var framesToWaitBeforeTransition = 30
    
    fileprivate var videoWriter: AVAssetWriter?
    fileprivate var videoExporter = VideoExporter()
    fileprivate var timescale = 10000000
    fileprivate var transitionRate: Double = 1
    fileprivate var isMixed = false
    fileprivate var isMovement = false
    fileprivate let fadeOffset: CGFloat = 30
    fileprivate let mediaInputQueue = DispatchQueue(label: "mediaInputQueue")
    fileprivate let flags = CVPixelBufferLockFlags(rawValue: 0)
    
    fileprivate var exportTimeRate: Float = 0.0
    fileprivate var waitTranstionTimeRate: Float = 0
    fileprivate var transitionTimeRate: Float = 0
    fileprivate var writerTimeRate: Float = 0.9 {
        didSet {
            self.calculatorTimeRate()
        }
    }
    
    fileprivate var currentProgress: Float = 0.0 {
        didSet {
            self.progress?(self.currentProgress)
        }
    }
    
    public override init() {
        super.init()
    }
    
    public convenience init(images: [UIImage?], transition: ImageTransition) {
        self.init()
        
        self.images = images
        self.transition = transition
        self.isMovement = false
    }
    
    public convenience init(images: [UIImage?], movement: ImageMovement) {
        self.init()
        
        self.images = images
        self.movement = movement
        self.isMovement = true
    }
    
    public func exportVideo(audio: AVURLAsset?, audioTimeRange: CMTimeRange?, completed: @escaping CompletedCombineBlock) -> VideoMaker {
        self.createDirectory()
        self.currentProgress = 0.0
        self.combineVideo { (success, url) in
            if success && url != nil {
                let video = AVURLAsset(url: url!)
                let item = VideoItem(video: video, audio: audio, audioTimeRange: audioTimeRange)
                self.videoExporter = VideoExporter(withe: item)
                self.videoExporter.export()
                let timeRate = self.currentProgress
                self.videoExporter.exportingBlock = { exportCompleted, progress, videoURL, error in
                    
                    DispatchQueue.main.async {
                        self.currentProgress = exportCompleted ? 1 : timeRate + (progress ?? 1) * self.exportTimeRate
                        completed(exportCompleted, videoURL)
                    }
                }
            } else {
                completed(false, nil)
            }
        }
        
        return self
    }
    
    public func cancelExport() {
        self.videoWriter?.cancelWriting()
        self.videoExporter.cancelExport()
    }
    
    fileprivate func calculateTime() {
        guard self.images.isEmpty == false else { return }
        
        let isFadeLong = self.transition == .crossFadeLong
        let hasSetDuration = self.videoDuration != nil
        self.timescale = hasSetDuration ? 100000 : 1
        let average = hasSetDuration ? Int(self.videoDuration! * self.timescale / self.images.count) : 2
        
        if self.isMovement {
            self.frameDuration = 0
            self.transitionDuration = hasSetDuration ? average : 2
        } else {
            self.frameDuration = hasSetDuration ? average : (isFadeLong ? 3 : 2)
            self.transitionDuration = isFadeLong ? Int(self.frameDuration * 2 / 3 ): Int(self.frameDuration / 2)
        }
        
        let frame = self.isMovement ? 20 : 60
        self.transitionFrameCount = Int(frame * self.transitionDuration / self.timescale)
        self.framesToWaitBeforeTransition = isFadeLong ? self.transitionFrameCount / 3 : self.transitionFrameCount / 2
        
        self.transitionRate = 1 / (Double(self.transitionDuration) / Double(self.timescale))
        self.transitionRate = self.transitionRate == 0 ? 1 : self.transitionRate
        
        if hasSetDuration == false {
            self.videoDuration = self.frameDuration * self.timescale * self.images.count
        }
        
        self.calculatorTimeRate()
    }
    
    fileprivate func makeImageFit() {
        var newImages = [UIImage?]()
        for image in self.images {
            if let image = image {
                
                let size = CGSize(width: self.size.width * definition, height: self.size.height * definition)
                
                let viewSize = self.isMovement && self.movement == .fade
                    ? CGSize(width: size.width + self.fadeOffset, height: size.height + self.fadeOffset)
                    : size
                let view = UIView(frame: CGRect(origin: .zero, size: viewSize))
                view.backgroundColor = UIColor.black
                let imageView = UIImageView(image: image)
                imageView.contentMode = self.contentMode
                imageView.backgroundColor = UIColor.black
                imageView.frame = view.bounds
                view.addSubview(imageView)
                let newImage = UIImage(view: view)
                newImages.append(newImage)
            }
        }
        self.images = newImages
    }
    
    fileprivate func combineVideo(completed: CompletedCombineBlock?) {
        self.makeImageFit()
        if self.isMovement {
            if self.movement == .none {
                self.isMovement = false
                self.transition = .none
                self.makeTransitionVideo(transition: self.transition, completed: completed)
            } else {
                self.makeMovementVideo(movement: self.movement, completed: completed)
            }
            
        } else {
            self.makeTransitionVideo(transition: self.transition, completed: completed)
        }
    }
    
    fileprivate func makeMovementVideo(movement: ImageMovement, completed: CompletedCombineBlock?) {
        guard self.images.isEmpty == false else {
            completed?(false, nil)
            return
        }
        
        // path
        let path = K.Path.MovURL.appendingPathComponent("\(self.movement).mov")
        print(path)
        self.deletePreviousTmpVideo(url: path)
        
        // config
        self.calculateTime()
        
        // writer
        self.videoWriter = try? AVAssetWriter(outputURL: path, fileType: .mov)
        
        guard let videoWriter = self.videoWriter else {
            print("Create video writer failed")
            completed?(false, nil)
            return
        }
        
        // input
        let videoSettings = [
            AVVideoCodecKey: AVVideoCodecH264,
            AVVideoWidthKey: self.size.width,
            AVVideoHeightKey: self.size.height
            ] as [String : Any]
        
        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoWriter.add(writerInput)
        
        // adapter
        let bufferAttributes = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB)
        ]
        let bufferAdapter = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerInput, sourcePixelBufferAttributes: bufferAttributes)
            
        self.startCombine(
            videoWriter: videoWriter,
            writerInput: writerInput,
            bufferAdapter: bufferAdapter,
            completed: { (success, url) in
                completed?(success, path)
        })
    }
    
    fileprivate func makeTransitionVideo(transition: ImageTransition, completed: CompletedCombineBlock?) {
        guard self.images.isEmpty == false else {
            completed?(false, nil)
            return
        }
        
        self.calculateTime()
        
        // MARK: - crossFadeLong
        if self.transition == .crossFadeLong {
            self.transition = .crossFade
        }
        
        // Config
        self.isMixed = self.transition == .wipeMixed || self.transition == .slideMixed || self.transition == .pushMixed
        self.changeNextIfNeeded()
        
        // video path
        let path = K.Path.MovURL.appendingPathComponent("\(transition).mov")
        print(path)
        self.deletePreviousTmpVideo(url: path)
        
        // writer
        self.videoWriter = try? AVAssetWriter(outputURL: path, fileType: .mov)
        
        guard let videoWriter = self.videoWriter else {
            print("Create video writer failed")
            completed?(false, nil)
            return
        }
        
        // input
        let videoSettings = [
            AVVideoCodecKey: AVVideoCodecH264,
            AVVideoWidthKey: self.size.width,
            AVVideoHeightKey: self.size.height
        ] as [String : Any]
        
        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoWriter.add(writerInput)
        
        // adapter
        let bufferAttributes = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB)
        ]
        let bufferAdapter = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerInput, sourcePixelBufferAttributes: bufferAttributes)
        
        
        self.startCombine(
            videoWriter: videoWriter,
            writerInput: writerInput,
            bufferAdapter: bufferAdapter,
            completed: { (success, url) in
                completed?(success, path)
        })
    }
    
    fileprivate func startCombine(videoWriter: AVAssetWriter,
               writerInput: AVAssetWriterInput,
               bufferAdapter: AVAssetWriterInputPixelBufferAdaptor,
               completed: CompletedCombineBlock?)
    {
        
        videoWriter.startWriting()
        videoWriter.startSession(atSourceTime: CMTime.zero)
        
        var presentTime = CMTime(seconds: 0, preferredTimescale: Int32(self.timescale))
        var i = 0
        
        writerInput.requestMediaDataWhenReady(on: self.mediaInputQueue) { 
            while true {
                if i >= self.images.count {
                    break
                }
                
                let duration = self.isMovement ? self.transitionDuration : self.frameDuration
                presentTime = CMTimeMake(value: Int64(i * duration), timescale: Int32(self.timescale))
                
                let presentImage = self.images[i]
                let nextImage: UIImage? = self.images.count > 1 && i != self.images.count - 1 ? self.images[i + 1] : nil
                
                presentTime = self.isMovement
                    ? self.appendMovementBuffer(
                        at: i,
                        presentImage: presentImage,
                        nextImage: nextImage,
                        time: presentTime,
                        writerInput: writerInput,
                        bufferAdapter: bufferAdapter
                    )
                    : self.appendTransitionBuffer(
                        at: i,
                        presentImage: presentImage,
                        nextImage: nextImage,
                        time: presentTime,
                        writerInput: writerInput,
                        bufferAdapter: bufferAdapter
                    )
                
                self.images[i] = nil
                i += 1
                self.changeNextIfNeeded()
            }
            
            writerInput.markAsFinished()
            videoWriter.finishWriting {
                DispatchQueue.main.async {
                    print("finished")
                    print(videoWriter.error ?? "no error")
                    completed?(videoWriter.error == nil, nil)
                }
            }
        }
    }
    
    fileprivate func appendTransitionBuffer(at position: Int,
                                  presentImage: UIImage?,
                                  nextImage: UIImage?,
                                  time: CMTime,
                                  writerInput: AVAssetWriterInput,
                                  bufferAdapter: AVAssetWriterInputPixelBufferAdaptor) -> CMTime
    {
       
        var presentTime = time
        
        if let cgImage = presentImage?.cgImage {
            if let buffer = self.transitionPixelBuffer(fromImage: cgImage, toImage: nextImage?.cgImage, with: .none, rate: 0) {
                
                while !writerInput.isReadyForMoreMediaData {
                    Thread.sleep(forTimeInterval: 0.1)
                }
                
                bufferAdapter.append(buffer, withPresentationTime: presentTime)
                self.currentProgress += self.waitTranstionTimeRate
                
                let transitionTime = CMTimeMake(value: Int64(self.transitionDuration), timescale: Int32(self.transitionFrameCount * self.timescale))
                presentTime = CMTimeAdd(presentTime, CMTimeMake(value: Int64(self.frameDuration - self.transitionDuration), timescale: Int32(self.timescale)))
                
                if position + 1 < self.images.count {
                    if self.transition != .none {
                        let framesToTransitionCount = self.transitionFrameCount - self.framesToWaitBeforeTransition
                        
                        let timeRate = self.currentProgress
                        for j in 1...framesToTransitionCount {
                            
                            let rate: CGFloat = CGFloat(Double(j) / Double(framesToTransitionCount))
                            
                            if let transitionBuffer = self.transitionPixelBuffer(fromImage: cgImage, toImage: nextImage?.cgImage, with: self.transition, rate: rate) {
                                
                                while !writerInput.isReadyForMoreMediaData {
                                    Thread.sleep(forTimeInterval: 0.1)
                                }

                                bufferAdapter.append(transitionBuffer, withPresentationTime: presentTime)
                                
                                self.currentProgress = timeRate + self.transitionTimeRate * Float(rate)
                                presentTime = CMTimeAdd(presentTime, transitionTime)
                            }
                        }
                    }
                }
            }
        }
        return presentTime
    }
    
    fileprivate func appendMovementBuffer(at position: Int,
                              presentImage: UIImage?,
                              nextImage: UIImage?,
                              time: CMTime,
                              writerInput: AVAssetWriterInput,
                              bufferAdapter: AVAssetWriterInputPixelBufferAdaptor) -> CMTime
    {
        var presentTime = time
        
        if let cgImage = presentImage?.cgImage {
            let movementTime = CMTimeMake(value: Int64(self.transitionDuration), timescale: Int32(self.transitionFrameCount * self.timescale))
            
            let timeRate = self.currentProgress
            for j in 1...self.transitionFrameCount {
                let rate: CGFloat = CGFloat(Double(j) / Double(self.transitionFrameCount))
                
                if let movementBuffer = self.movementPixelBuffer(cgImage: cgImage, with: self.movement, rate: rate) {
                    
                    while !writerInput.isReadyForMoreMediaData {
                        Thread.sleep(forTimeInterval: 0.1)
                    }
                    
                    bufferAdapter.append(movementBuffer, withPresentationTime: presentTime)
                    
                    self.currentProgress = timeRate + self.transitionTimeRate * Float(rate)
                    presentTime = CMTimeAdd(presentTime, movementTime)
                }
            }
        }
        
        return presentTime
    }
    
    fileprivate func movementPixelBuffer(cgImage: CGImage, with movement: ImageMovement, rate: CGFloat) -> CVPixelBuffer? {
        
        let movementBuffer = autoreleasepool { () -> CVPixelBuffer? in
            guard let buffer = self.createBuffer() else { return nil }
            
            CVPixelBufferLockBaseAddress(buffer, self.flags)
            
            let pxdata = CVPixelBufferGetBaseAddress(buffer)
            let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
            
            let context = CGContext(
                data: pxdata,
                width: Int(self.size.width),
                height: Int(self.size.height),
                bitsPerComponent: 8,
                bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                space: rgbColorSpace,
                bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
            )
            context?.interpolationQuality = self.quarity
            self.performMovementDrawing(cxt: context, cgImage: cgImage, with: self.movement, rate: rate)
            
            CVPixelBufferUnlockBaseAddress(buffer, self.flags)
            
            return buffer
        }
        return movementBuffer
    }
    
    fileprivate func transitionPixelBuffer( fromImage: CGImage, toImage: CGImage?, with transition: ImageTransition, rate: CGFloat) -> CVPixelBuffer? {
        let transitionBuffer = autoreleasepool { () -> CVPixelBuffer? in
            guard let buffer = self.createBuffer() else { return nil }
            
            CVPixelBufferLockBaseAddress(buffer, self.flags)
            
            let pxdata = CVPixelBufferGetBaseAddress(buffer)
            let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
            
            let context = CGContext(
                data: pxdata,
                width: Int(self.size.width),
                height: Int(self.size.height),
                bitsPerComponent: 8,
                bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                space: rgbColorSpace,
                bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
            )
            context?.interpolationQuality = self.quarity
            
            self.performTransitionDrawing(cxt: context, from: fromImage, to: toImage, with: transition, rate: rate)
            
            CVPixelBufferUnlockBaseAddress(buffer, self.flags)
            
            return buffer
        }
        return transitionBuffer
    }
    
    // Transition
    fileprivate func performTransitionDrawing(cxt: CGContext?, from: CGImage, to: CGImage?, with transition: ImageTransition, rate: CGFloat) {
        let toSize = to == nil ? CGSize.zero : CGSize(width: CGFloat(to!.width), height: CGFloat(to!.height))
        
        let fromFitSize = self.size
        let toFitSize = self.size
        
        if to == nil {
            let rect = CGRect(x: 0, y: 0, width: fromFitSize.width, height: fromFitSize.height)
            cxt?.concatenate(.identity)
            cxt?.draw(from, in: rect)
            return
        }
        
        switch transition {
            
        // MARK: - none
        case .none:
            
            let rect = CGRect(x: 0, y: 0, width: fromFitSize.width, height: fromFitSize.height)
            cxt?.concatenate(.identity)
            cxt?.draw(from, in: rect)
            
        // MARK: - crossFade
        case .crossFade:
            
            let fromRect = CGRect(origin: .zero, size: fromFitSize)
            let toRect = CGRect(origin: .zero, size: toFitSize)
            
            cxt?.draw(from, in: fromRect)
            cxt?.beginTransparencyLayer(auxiliaryInfo: nil)
            cxt?.setAlpha(rate)
            cxt?.draw(to!, in: toRect)
            cxt?.endTransparencyLayer()
        
        // MARK: - crossFadeUp
        case .crossFadeUp:
            
            // Expand twice
            let width = (rate + 1) * fromFitSize.width
            let height = (rate + 1) * fromFitSize.height
            
            let fromRect = CGRect(
                x: -(width - fromFitSize.width) / 2,
                y: -(height - fromFitSize.width) / 2,
                width: width,
                height: height
            )
            
            let toRect = CGRect(origin: .zero, size: toFitSize)
            
            cxt?.draw(from, in: fromRect)
            cxt?.beginTransparencyLayer(auxiliaryInfo: nil)
            cxt?.setAlpha(rate)
            cxt?.draw(to!, in: toRect)
            cxt?.endTransparencyLayer()
            
        // MARK: - crossFadeDown
        case .crossFadeDown:
            
            // 1 -> 0
            let width = (1 - rate) * fromFitSize.width
            let height = (1 - rate) * fromFitSize.height
            
            let fromRect = CGRect(
                x: (fromFitSize.width - width) / 2,
                y: (fromFitSize.height - height) / 2,
                width: width,
                height: height
            )
            
            let toRect = CGRect(origin: .zero, size: toFitSize)
            
            // cover previous fps
            cxt?.setFillColor(red: 0, green: 0, blue: 0, alpha: 1)
            cxt?.setStrokeColor(UIColor.black.cgColor)
            cxt?.fill(CGRect(origin: .zero, size: self.size))
            
            cxt?.draw(from, in: fromRect)
            cxt?.beginTransparencyLayer(auxiliaryInfo: nil)
            cxt?.setAlpha(rate)
            cxt?.draw(to!, in: toRect)
            cxt?.endTransparencyLayer()
            
        // MARK: - wipeRight
        case .wipeRight:
            
            let fromRect = CGRect(
                x: 0,
                y: 0,
                width: fromFitSize.width,
                height: fromFitSize.height
            )
            
            let toRect = CGRect(
                x: 0,
                y: 0,
                width: toFitSize.width * rate,
                height: toFitSize.height
            )
            
            let clipRect = CGRect(
                x: 0,
                y: 0,
                width: toSize.width * rate,
                height: toSize.height
            )
            
            cxt?.draw(from, in: fromRect)
            if let mask = to?.cropping(to: clipRect) {
                cxt?.draw(mask, in: toRect)
            }
            
        // MARK: - wipeLeft
        case .wipeLeft:
            
            let fromRect = CGRect(
                x: 0,
                y: 0,
                width: fromFitSize.width,
                height: fromFitSize.height
            )
            
            let toRect = CGRect(
                x: (1 - rate) * self.size.width,
                y: 0,
                width: toFitSize.width * rate,
                height: toFitSize.height
            )
            
            let clipRect = CGRect(
                x: (1 - rate) * toSize.width,
                y: 0,
                width: toSize.width * rate,
                height: toSize.height
            )
            
            cxt?.draw(from, in: fromRect)
            if let mask = to?.cropping(to: clipRect) {
                cxt?.draw(mask, in: toRect)
            }

        // MARK: - wipeUp
        case .wipeUp:
            
            let fromRect = CGRect(
                x: 0,
                y: 0,
                width: fromFitSize.width,
                height: fromFitSize.height
            )
            
            let toRect = CGRect(
                x: 0,
                y: 0,
                width: toFitSize.width,
                height: toFitSize.height * rate
            )
            
            let clipRect = CGRect(
                x: 0,
                y: (1 - rate) * toSize.height,
                width: toSize.width,
                height: toSize.height * rate
            )
            
            cxt?.draw(from, in: fromRect)
            if let mask = to?.cropping(to: clipRect) {
                cxt?.draw(mask, in: toRect)
            }
            
        // MARK: - wipeDown
        case .wipeDown:
            
            let fromRect = CGRect(
                x: 0,
                y: 0,
                width: fromFitSize.width,
                height: fromFitSize.height
            )
            
            let toRect = CGRect(
                x: 0,
                y: (1 - rate) * toFitSize.height,
                width: toFitSize.width,
                height: toFitSize.height * rate
            )
            
            let clipRect = CGRect(
                x: 0,
                y: 0,
                width: toSize.width,
                height: toSize.height * rate
            )
            
            cxt?.draw(from, in: fromRect)
            if let mask = to?.cropping(to: clipRect) {
                cxt?.draw(mask, in: toRect)
            }
            
        // MARK: - slideLeft
        case .slideLeft:
            
            let fromRect = CGRect(
                x: 0,
                y: 0,
                width: fromFitSize.width,
                height: fromFitSize.height
            )
            
            let toRect = CGRect(
                x: (1 - rate) * self.size.width,
                y: 0,
                width: toFitSize.width,
                height: toFitSize.height
            )
            
            cxt?.draw(from, in: fromRect)
            cxt?.draw(to!, in: toRect)
            
        // MARK: - slideRight
        case .slideRight:
            
            let fromRect = CGRect(
                x: 0,
                y: 0,
                width: fromFitSize.width,
                height: fromFitSize.height
            )
            
            let toRect = CGRect(
                x: -(1 - rate) * self.size.width,
                y: 0,
                width: toFitSize.width,
                height: toFitSize.height
            )
            
            cxt?.draw(from, in: fromRect)
            cxt?.draw(to!, in: toRect)
            
        // MARK: - slideUp
        case .slideUp:
            
            let fromRect = CGRect(
                x: 0,
                y: 0,
                width: fromFitSize.width,
                height: fromFitSize.height
            )
            
            let toRect = CGRect(
                x: 0,
                y: -(1 - rate) * self.size.width,
                width: toFitSize.width,
                height: toFitSize.height
            )
            
            cxt?.draw(from, in: fromRect)
            cxt?.draw(to!, in: toRect)
            
        // MARK: - slideDown
        case .slideDown:
            
            let fromRect = CGRect(
                x: 0,
                y: 0,
                width: fromFitSize.width,
                height: fromFitSize.height
            )
            
            let toRect = CGRect(
                x: 0,
                y: (1 - rate) * self.size.width,
                width: toFitSize.width,
                height: toFitSize.height
            )
            
            cxt?.draw(from, in: fromRect)
            cxt?.draw(to!, in: toRect)
            
        // MARK: - pushRight
        case .pushRight:
            
            let fromRect = CGRect(
                x: rate * self.size.width,
                y: 0,
                width: fromFitSize.width,
                height: fromFitSize.height
            )
            
            let toRect = CGRect(
                x: -(1 - rate) * self.size.width,
                y: 0,
                width: toFitSize.width,
                height: toFitSize.height
            )
            
            cxt?.draw(from, in: fromRect)
            cxt?.draw(to!, in: toRect)
            
        // MARK: - pushLeft
        case .pushLeft:
            
            let fromRect = CGRect(
                x: -rate * self.size.width,
                y: 0,
                width: fromFitSize.width,
                height: fromFitSize.height
            )
            
            let toRect = CGRect(
                x: (1 - rate) * self.size.width,
                y: 0,
                width: toFitSize.width,
                height: toFitSize.height
            )
            
            cxt?.draw(from, in: fromRect)
            cxt?.draw(to!, in: toRect)
            
        // MARK: - pushUp
        case .pushUp:
            
            let fromRect = CGRect(
                x: 0,
                y: rate * self.size.height,
                width: fromFitSize.width,
                height: fromFitSize.height
            )
            
            let toRect = CGRect(
                x: 0,
                y: -(1 - rate) * self.size.height,
                width: toFitSize.width,
                height: toFitSize.height
            )
            
            cxt?.draw(from, in: fromRect)
            cxt?.draw(to!, in: toRect)
            
        // MARK: - pushDown
        case .pushDown:
            
            let fromRect = CGRect(
                x: 0,
                y: -rate * self.size.height,
                width: fromFitSize.width,
                height: fromFitSize.height
            )
            
            let toRect = CGRect(
                x: 0,
                y: (1 - rate) * self.size.height,
                width: toFitSize.width,
                height: toFitSize.height
            )
            
            cxt?.draw(from, in: fromRect)
            cxt?.draw(to!, in: toRect)
            
        default:
            break
        }
    }
    
    fileprivate func performMovementDrawing(cxt: CGContext?, cgImage: CGImage, with movement: ImageMovement, rate: CGFloat) {
        var fromFitSize = self.size
        
        switch movement {
        case .fade:
            
            fromFitSize.width += fadeOffset
            fromFitSize.height += fadeOffset
            
            var rect = CGRect.zero
            
            switch self.movementFade {
            case .upLeft:
                
                rect = CGRect(
                    x: -fadeOffset * (rate),
                    y: fadeOffset * (rate) - fadeOffset,
                    width: fromFitSize.width,
                    height: fromFitSize.height
                )
                
            case .upRight:
                
                rect = CGRect(
                    x: fadeOffset * (rate) - fadeOffset,
                    y: fadeOffset * (rate) - fadeOffset,
                    width: fromFitSize.width,
                    height: fromFitSize.height
                )
                
            case .bottomLeft:
                
                rect = CGRect(
                    x: -fadeOffset * (rate),
                    y: -fadeOffset * (rate),
                    width: fromFitSize.width,
                    height: fromFitSize.height
                )
                
            case .bottomRight:
                
                rect = CGRect(
                    x: fadeOffset * (rate) - fadeOffset,
                    y: -fadeOffset * (rate),
                    width: fromFitSize.width,
                    height: fromFitSize.height
                )
            }
            
            cxt?.setFillColor(red: 0, green: 0, blue: 0, alpha: 1)
            cxt?.setStrokeColor(UIColor.black.cgColor)
            cxt?.fill(CGRect(origin: .zero, size: self.size))
            cxt?.draw(cgImage, in: rect)
            
        case .scale:
            
            let width = rate * fadeOffset + fromFitSize.width
            let height = rate * fadeOffset + fromFitSize.height
            
            let rect = CGRect(
                x: -(width - fromFitSize.width) / 2,
                y: -(height - fromFitSize.width) / 2,
                width: width,
                height: height
            )
            
            cxt?.draw(cgImage, in: rect)
            
            break
        default:
            break
        }
    }
    
    fileprivate func createBuffer() -> CVPixelBuffer? {
        
        let options: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: NSNumber(value: true),
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: NSNumber(value: true)
        ]
        
        var pxBuffer: CVPixelBuffer?
        
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(self.size.width),
            Int(self.size.height),
            kCVPixelFormatType_32ARGB,
            options as CFDictionary?,
            &pxBuffer
        )
        
        let success = status == kCVReturnSuccess && pxBuffer != nil
        return success ? pxBuffer : nil
    }
    
    fileprivate func deletePreviousTmpVideo(url: URL) {
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
    }
    
    fileprivate func changeNextIfNeeded() {
        if self.isMovement == false {
            if self.isMixed {
                self.transition = self.transition.next
            }
        } else {
            if self.movement == .fade {
                self.movementFade = self.movementFade.next
            }
        }
    }
    
    fileprivate func changeWipeNext() {
        if self.isMixed {
            self.transition = self.transition.wipeNext
        }
    }
    
    fileprivate func changeSlideNext() {
        if self.isMixed {
            self.transition = self.transition.slideNext
        }
    }
    
    fileprivate func changePushNext() {
        if self.isMixed {
            self.transition = self.transition.pushNext
        }
    }
    
    fileprivate func calculatorTimeRate() {
        if self.images.isEmpty == false {
            self.exportTimeRate = 1 - self.writerTimeRate
            let frameTimeRate = self.writerTimeRate / Float(self.images.count)
            self.waitTranstionTimeRate = self.isMovement ? 0 : frameTimeRate * 0.2
            self.transitionTimeRate = frameTimeRate - self.waitTranstionTimeRate
        }
    }
    
    fileprivate  func createDirectory() {
        try? FileManager.default.createDirectory(at: K.Path.MovURL, withIntermediateDirectories: true, attributes: nil)
    }
}
