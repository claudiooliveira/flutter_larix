import AVFoundation
import CoreImage
import SwiftUI
import LarixUI
import LarixSupport

protocol SilenceGeneratorDelegate {
    func putEmptyVideo(_ buffer: CVPixelBuffer, time: CMTime)
    func putEmptyAudio(_ buffer: CMSampleBuffer)
    func onDownloadFinish(layer: ImageLayer, location: URL, suggestedFilename: String) -> URL?
}

// Generate empty audio and video frames during pause
class SilenceGenerator: CompositeImageLayerDelegate {
    
    private var active: Bool = false
    private var audioSessionInterruption: Bool = false

    private var currentAudioFormat: AudioStreamBasicDescription?
    private var lastAudioSampleNum: Int = 0
    private var lastAudioFrameTime: Double = 0.0
    private var realtimeOffset: Double = 0.0
    private var audioFrameTimer: Timer?
    private let audioFrameInterval: TimeInterval = 1.0/50.0
    
    private var lastVideorameTime: Double = 0.0
    private var blackFrameTimer: Timer?
    private var blackFrameTime:CFTimeInterval = 0
    private var blackFrameOffset:CFTimeInterval = 0
    private var blackFrame: CVPixelBuffer?

    private var streamWidth: Int = 0
    private var streamHeight: Int = 0
    
    private var pauseOverlay: CompositeImageLayer
    private var displayOverlay = false
    private var resetBlackFrame = false
    private var overlays: [ImageLayer] = []
    
    private let ciContext: CIContext
    private var delegate: SilenceGeneratorDelegate

    weak public var imageLayerPreview: ImagePreviewOverlay? {
        didSet {
            imageLayerPreview?.setPauseImage(pauseOverlay.outputImage?.cgImage)
        }
    }

    init(context: CIContext, delegate: SilenceGeneratorDelegate) {
        self.ciContext = context
        self.delegate = delegate
        pauseOverlay = CompositeImageLayer()
        pauseOverlay.delegate = self
    }
    
    func setStreamSize(width: Int, height: Int) {
        streamWidth = width
        streamHeight = height
        pauseOverlay.size = CGSize(width: width, height: height)
        if !overlays.isEmpty {
            pauseOverlay.loadList(overlays)
            displayOverlay = true
            overlays.removeAll()
        }
    }
    
    func setOverlays(_ overlays: [ImageLayer]) {
        if streamWidth > 0 && streamHeight > 0 {
            pauseOverlay.loadList(overlays)
            displayOverlay = !overlays.isEmpty
            resetBlackFrame = true
        } else {
            self.overlays = overlays
        }
    }
    
    // Store active audio details to generate silence in same format
    func handleAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        if audioFrameTimer != nil || blackFrameTimer != nil {
            audioFrameTimer?.invalidate()
            fillGap(to: sampleBuffer, minPeriod: 0.05)
            audioFrameTimer = nil
        }

        let ts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let duration = CMSampleBufferGetDuration(sampleBuffer)
        let num = CMSampleBufferGetNumSamples(sampleBuffer)
        //LogVerbose("audioSampleBuffer PTS \(ts.seconds) duration \(duration.seconds)")
        realtimeOffset = ts.seconds - CACurrentMediaTime()
        lastAudioFrameTime = ts.seconds + duration.seconds
        lastAudioSampleNum = num
        if let format = CMSampleBufferGetFormatDescription(sampleBuffer),
           let audioDesc = CMAudioFormatDescriptionGetStreamBasicDescription(format)?.pointee {
            currentAudioFormat = audioDesc
        }
    }
    
    func handleVideoSampleBuffer(_ sampleBuffer: CMSampleBuffer) -> Bool {
        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        lastVideorameTime = pts.seconds
        if !active && !audioSessionInterruption {
            let seconds = CACurrentMediaTime()
            blackFrameOffset = pts.seconds - seconds
            //LogVerbose("video buffer \(pts.seconds)\toffset \(blackFrameOffset)")
        }
        
        if blackFrameTime > 0 {
            if pts.seconds < blackFrameTime + 0.001 {
                LogInfo("Skip frame after black frame: \(blackFrameTime) > \(pts.seconds)")
                return false
            } else {
                blackFrameTime = 0
            }
        }
        return true
    }
    
    func setAudioInterruption(started: Bool) {
        LogInfo("SilenceGenerator:setInterruption \(started)")
        audioSessionInterruption = started
    }
    
    func start(fps: Double, withAudio: Bool) {
        LogInfo("SilenceGenerator start")
        
        if fps > 0 {
            startBlackFrameTimer(fps: fps)
        }
        if withAudio {
            if audioFrameTimer != nil {
                audioFrameTimer?.invalidate()
            }
            audioFrameTimer = Timer.scheduledTimer(withTimeInterval: audioFrameInterval, repeats: true) { (_) in
                StreamerSingleton.sharedQueue.async {
                    self.generateByTimer()
                }
            }
            active = true
        }
    }
    
    func stop() {
        audioFrameTimer?.invalidate()
        stopBlackFrameTimer()
        active = false
    }

    func stopAudio() {
        audioFrameTimer?.invalidate()
        if blackFrameTimer == nil {
            active = false
        }
    }

    func outputBlackFrame(withPresentationTime time: CMTime) {
        if (resetBlackFrame) {
            blackFrame = nil
            resetBlackFrame = false
            
        }
        if (blackFrame == nil) {
            
            let outputOptions = [kCVPixelBufferMetalCompatibilityKey as String: true,
                                 kCVPixelBufferCGImageCompatibilityKey as String: true,
                                 kCVPixelBufferIOSurfacePropertiesKey as String: [:]] as CFDictionary

            CVPixelBufferCreate(kCFAllocatorDefault,
                                streamWidth, streamHeight,
                                kCVPixelFormatType_32BGRA,
                                outputOptions,
                                &blackFrame)

            if displayOverlay, let image = pauseOverlay.outputImage {
                ciContext.render(image, to: blackFrame!)
                imageLayerPreview?.setPauseImage(pauseOverlay.outputImage?.cgImage)

            }
        }
        if let blackFrame = blackFrame {
            delegate.putEmptyVideo(blackFrame, time: time)
        } else {
            LogError("Failed to create pixel buffer")
        }
    }
    
    private func fillGap(to sampleBuffer: CMSampleBuffer, minPeriod: Double) {
        let ts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        let ts_time = ts.seconds
        let dt = ts_time - lastAudioFrameTime
        if dt < minPeriod { return }
        let count = CMSampleBufferGetNumSamples(sampleBuffer)
        guard let format = CMSampleBufferGetFormatDescription(sampleBuffer),
            let audioDesc = CMAudioFormatDescriptionGetStreamBasicDescription(format)?.pointee else {
            return
        }

        var deltaSamples = Int(ceil((ts.seconds - lastAudioFrameTime) * audioDesc.mSampleRate))
        deltaSamples -= deltaSamples % 2
        var pts_val = Int64(lastAudioFrameTime * audioDesc.mSampleRate)
        while deltaSamples > 0 {
            let samples = deltaSamples > count * 3 / 2 ? count : deltaSamples //Generate block with at most 1.5x of input block length
            LogInfo("black frame: generatng \(samples) empty samples @ \(audioDesc.mSampleRate)")
            let pts = CMTime(value: pts_val, timescale: CMTimeScale(audioDesc.mSampleRate))
            if let buf = generatePCM(pts: pts, frameCount: samples, audioDesc: audioDesc) {
                delegate.putEmptyAudio(buf)
            }
            pts_val += Int64(samples)
            deltaSamples -= samples
        }
    }
    
    private func generateByTimer() {
        guard let format = currentAudioFormat else { return }
        let sampleRate = format.mSampleRate
        let adjustedTime = realtimeOffset + CACurrentMediaTime()
        let duration = adjustedTime - lastAudioFrameTime
        var frameCount = Int(floor(duration * format.mSampleRate))
        var frameTime = lastAudioFrameTime
        let chunkDuration = Double(lastAudioSampleNum) / sampleRate
        while frameCount >= lastAudioSampleNum {
            LogInfo("Generating \(lastAudioSampleNum) empty audio samples at \(frameTime)")
            let pts = CMTime(seconds: frameTime, preferredTimescale: CMTimeScale(sampleRate))
            if let buf = generatePCM(pts: pts, frameCount: lastAudioSampleNum, audioDesc: format) {
                delegate.putEmptyAudio(buf)
            }
            frameTime += chunkDuration
            frameCount -= lastAudioSampleNum
        }
        lastAudioFrameTime = frameTime
    }
    
    private func generatePCM(pts: CMTime, frameCount: CMItemCount, audioDesc: AudioStreamBasicDescription) -> CMSampleBuffer? {
        var sampleBuffer: CMSampleBuffer? = nil
        
        let dataLen:Int = Int(frameCount) * Int(audioDesc.mChannelsPerFrame) * 2
        var bbuf: CMBlockBuffer? = nil

        var status = CMBlockBufferCreateWithMemoryBlock(allocator: kCFAllocatorDefault,
                                                        memoryBlock: nil,
                                                        blockLength: dataLen,
                                                        blockAllocator: nil,
                                                        customBlockSource: nil,
                                                        offsetToData: 0,
                                                        dataLength: dataLen,
                                                        flags: 0,
                                                        blockBufferOut: &bbuf)
        
        guard status == kCMBlockBufferNoErr, bbuf != nil else {
            LogError("Failed to create memory block")
            return nil
        }

        status = CMBlockBufferFillDataBytes(with: 0, blockBuffer: bbuf!, offsetIntoDestination: 0, dataLength: dataLen)
        guard status == kCMBlockBufferNoErr else {
            LogError("Failed to fill memory block")
            return nil
        }
        
        var formatDesc: CMAudioFormatDescription?
        var descVar = audioDesc
        status = CMAudioFormatDescriptionCreate(allocator: kCFAllocatorDefault,
                                                asbd: &descVar,
                                                layoutSize: 0,
                                                layout: nil,
                                                magicCookieSize: 0,
                                                magicCookie: nil,
                                                extensions: nil,
                                                formatDescriptionOut: &formatDesc)
        guard status == noErr, formatDesc != nil else {
            LogError("Failed to create format description")
            return nil
        }

        status = CMAudioSampleBufferCreateReadyWithPacketDescriptions(allocator: kCFAllocatorDefault,
                                                                      dataBuffer: bbuf!,
                                                                      formatDescription: formatDesc!,
                                                                      sampleCount: frameCount,
                                                                      presentationTimeStamp: pts,
                                                                      packetDescriptions: nil,
                                                                      sampleBufferOut: &sampleBuffer)

        guard  status == noErr, sampleBuffer != nil else {
            LogError("Failed to create sampleBuffer")
            return nil
        }
        return sampleBuffer
    }
    

    
    private func startBlackFrameTimer(fps: Double) {
        let interval:TimeInterval = fps < 1.0 ? 1.0/30.0 : 1.0 / fps
        
        if let timer = blackFrameTimer {
            timer.invalidate()
        }
        blackFrameTime = 0
        LogVerbose("Start black frame timer at \(fps) FPS  offset \(blackFrameOffset)")
        DispatchQueue.main.async {
            self.blackFrameTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true, block: { (_) in
                let seconds = CACurrentMediaTime() + self.blackFrameOffset
                self.drawBlackFrame(ts: seconds)
            })
            let seconds = CACurrentMediaTime() + self.blackFrameOffset
            if seconds - self.lastVideorameTime > 1.5/fps {
                //Add itermediate frames
                var curTs = self.lastVideorameTime + 1.0/fps
                while curTs < seconds {
                    self.drawBlackFrame(ts: curTs)
                    curTs += 1.0/fps
                }
            }
        }
    }
    
    private func stopBlackFrameTimer() {
        if let timer = blackFrameTimer {
            LogVerbose("Stop black frame timer")
            timer.invalidate()
            blackFrameTimer = nil
        }
    }
    
    private func drawBlackFrame(ts: CFTimeInterval) {
        blackFrameTime = ts
        //DDLogVerbose("Draw black frame at \(ts)")
        let time = CMTime(seconds: ts, preferredTimescale: 1000)
        outputBlackFrame(withPresentationTime: time)
    }
    
    func onImageLoadComplete() {
        DispatchQueue.main.async {

            if self.displayOverlay,
               let image = self.pauseOverlay.outputImage,
               let blackFrame = self.blackFrame {
                if image.extent.size == CGSize.zero {
                    LogError("onImageLoadComplete: Bad image")
                    return
                }

                self.ciContext.render(image, to: blackFrame)
                self.imageLayerPreview?.setPauseImage(self.pauseOverlay.outputImage?.cgImage)
            }
        }

    }

    func onDownloadFinish(layer: ImageLayer, location: URL, suggestedFilename: String) -> URL? {
        return delegate.onDownloadFinish(layer: layer, location: location, suggestedFilename: suggestedFilename)
    }
}
