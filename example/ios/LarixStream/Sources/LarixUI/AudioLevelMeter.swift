import Foundation
import UIKit
import CoreMedia
import LarixObjC

public class AudioLevelMeter: UIView {
    public var redCount: Int = 4
    public var yellowCount: Int = 6
    public var ledCount: Int = 30
    public var channels: Int = 1 {
        didSet {
            DispatchQueue.main.async {
                self.arrangeLayers()
            }
        }
    }
    static let MAX_CHANNELS: Int = 2

    var measureInterval: Double = 0.1
    var rms: [Double] = Array<Double>(repeating: -100.0, count: MAX_CHANNELS)
    
    private var sum: [Double] = Array<Double>(repeating: 0.0, count: MAX_CHANNELS)
    private var count: Int32 = 0
    private var maskLayer: CALayer
    private var uvBar: [CAReplicatorLayer] = []
    private var led: [CALayer] = []
    private var gradient: CAGradientLayer
    private var w:CGFloat = 0
    private var h:CGFloat = 0
    
    private let dbRange:ClosedRange<Double> = -80.0...0.0
    private static let conversion16Base: Double = pow(2.0, 15)
    
    override init(frame: CGRect) {
        maskLayer = CALayer()
        gradient = CAGradientLayer()
        super.init(frame: frame)
        reset()
    }
    
    required init?(coder: NSCoder) {
        maskLayer = CALayer()
        gradient = CAGradientLayer()
        super.init(coder: coder)
        layer.backgroundColor = UIColor.clear.cgColor
        layer.contentsGravity = .bottomLeft
        gradient.colors = [UIColor.green.cgColor, UIColor.green.cgColor, UIColor.yellow.cgColor, UIColor.yellow.cgColor, UIColor.red.cgColor];
        let redPos =  Float(ledCount - redCount) / Float(ledCount)
        let yellowPos = Float(ledCount - redCount - yellowCount) / Float(ledCount)
        let locations = [0.0, (yellowPos-0.01), (yellowPos), (redPos-0.01), (redPos)] as [NSNumber]
        gradient.locations = locations
        
        gradient.frame = bounds
        layer.addSublayer(gradient)
      
        reset()
    }
    
    func reset() {
        rms = Array(repeating: dbRange.lowerBound, count: Self.MAX_CHANNELS)
        sum = Array(repeating: 0.0, count: Self.MAX_CHANNELS)
        count = 0
    }
    
    public func arrangeLayers() {
        w = bounds.width
        h = bounds.height
        let left = bounds.origin.x
        let top =  bounds.origin.y
        
        gradient.frame = bounds
        var tickSize: CGFloat = 1.0
        var offset = CATransform3D()
        layer.isGeometryFlipped = w <= h
        if (w > h) {
            tickSize = CGFloat(w) / CGFloat(ledCount)
            offset = CATransform3DMakeTranslation(tickSize, 0, 0)
            gradient.startPoint = CGPoint(x:0.0, y:0.5)
            gradient.endPoint = CGPoint(x:1.0, y:0.5)
        } else {
            tickSize = CGFloat(h) / CGFloat(ledCount)
            offset = CATransform3DMakeTranslation(0, tickSize, 0)
            gradient.startPoint = CGPoint(x:0.5, y:0.0)
            gradient.endPoint = CGPoint(x:0.5, y:1.0)
        }
        maskLayer.sublayers?.removeAll()
        led.removeAll()
        uvBar.removeAll()

        for i in 0..<channels {
            let chLed = CAReplicatorLayer()
            chLed.backgroundColor = UIColor.white.cgColor

            var frame = CGRect()
            if (w > h) {
                let barHeight = h / CGFloat(channels)
                frame = CGRect(x: left, y: top + CGFloat(i) * barHeight, width: w, height: barHeight)
                chLed.frame = CGRect(x: 0.0, y: 0.0, width: tickSize * 2.0 / 3.0, height: h * 0.9 / CGFloat(channels))

            } else {
                let barWidth = w / CGFloat(channels)
                frame = CGRect(x: left + CGFloat(i) * barWidth, y: top, width: barWidth, height: h)
                chLed.frame = CGRect(x: 0.0, y: 0.0, width: w * 0.9 / CGFloat(channels), height: tickSize * 2.0 / 3.0)
            }
            let bar = CAReplicatorLayer()
            bar.frame = frame
            bar.borderWidth = 0
            bar.backgroundColor = UIColor.clear.cgColor
            bar.instanceTransform = offset
            bar.repeatCount = 1
            bar.addSublayer(chLed)
            uvBar.append(bar)
            led.append(chLed)
            maskLayer.addSublayer(bar)
        }
        layer.mask = maskLayer
    }
    
    public func putBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer),
            let audioDesc = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc)?.pointee else { return }
        
        guard audioDesc.mFormatID == kAudioFormatLinearPCM, audioDesc.mBitsPerChannel == 16, audioDesc.mFormatFlags & 0xff == kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked else { return }
        let sampleChannels = Int32(audioDesc.mChannelsPerFrame)
        let neededSamples = Int32(floor(audioDesc.mSampleRate * measureInterval * Double(sampleChannels)))
        if count > neededSamples {
            //Already accumulated more then needed, process it now
            updateValue(sum: sum, count: count)
            sum = Array(repeating: 0, count: Self.MAX_CHANNELS)
            count = 0
        }
        let numSamples:Int32 = Int32(CMSampleBufferGetNumSamples(sampleBuffer))
        let currentPart:Int32 = max(0,min(numSamples, neededSamples-count))
        for i in 0..<channels {
            let offset = Int32(i) % sampleChannels
            sum[Int(i)] += AudioUtils.getSquared(sampleBuffer, offset: offset, count: currentPart, stride: sampleChannels)
        }
        count += currentPart
        if count < neededSamples {
            return
        }
        updateValue(sum: sum, count: count)
        sum = Array(repeating: 0, count: Self.MAX_CHANNELS)
        count = 0
        
        if numSamples > currentPart {
            for i in 0..<channels {
                let offset = Int32(i) % sampleChannels
                sum[i] = AudioUtils.getSquared(sampleBuffer, offset: currentPart+offset, count: numSamples-currentPart, stride: sampleChannels)
            }
            count = numSamples - currentPart
        }
    }
    
    private func updateValue(sum: [Double], count: Int32) {
        if count == 0 { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {return}
            let ch = min(self.uvBar.count, sum.count, self.rms.count)
            let lowerBound = self.dbRange.lowerBound
            let upperBound = self.dbRange.upperBound
            for i in 0..<ch {
                let v = sum[i] == 0 ? -100 :  10 * log(sqrt(sum[i]/Double(count)))
                let rms = self.rms[i] * 0.1 + v * 0.9
                self.rms[i] = rms
                let scale = CGFloat(max(0, rms - lowerBound) / (upperBound - lowerBound))
                let tickNum = round(scale * CGFloat(self.ledCount))
                self.uvBar[i].instanceCount = Int(tickNum)
            }

        }
    }
    
}

