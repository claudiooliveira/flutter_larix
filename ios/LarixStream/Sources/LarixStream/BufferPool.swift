import Foundation
import AVFoundation

/**
 Used by StreamerSingleCam/StreamerMultiCam rotateAndEncode functions to hold pool of  CVPixelBuffer (and optionally MTLTexture) instead of allocating new buffer for each frame.
 It reduced memory consuumption significantly
 */
class BufferPool {
    
    internal var streamWidth: Int
    internal var streamHeight: Int

    internal let bufferPoolSize = 2
    internal var outputBufferPool: [CVPixelBuffer] = []
    internal var outputTexurePool: [MTLTexture] = []
    internal var bufferIndex = -1
    internal var needInvalidate: Bool = false
    
    init(width: Int, height: Int) {
        streamWidth = width
        streamHeight = height
    }
    
    func invalidate() {
        needInvalidate = true
    }
    
    func createOutputBuffer(with inputFormatDescription: CMFormatDescription) -> CVPixelBuffer? {
        
        if needInvalidate {
            outputBufferPool.removeAll()
            outputTexurePool.removeAll()
        }
        
        bufferIndex = (bufferIndex + 1) % bufferPoolSize
        
        if bufferIndex < outputBufferPool.count  {
            return outputBufferPool[bufferIndex]
        }
        
        let inputMediaSubType = CMFormatDescriptionGetMediaSubType(inputFormatDescription)
        var pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: UInt(inputMediaSubType),
            kCVPixelBufferWidthKey as String: streamWidth,
            kCVPixelBufferHeightKey as String: streamHeight,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]
        
        // Get pixel buffer attributes and color space from the input format description
        if let inputFormatDescriptionExtension = CMFormatDescriptionGetExtensions(inputFormatDescription) as Dictionary? {
            let colorPrimaries = inputFormatDescriptionExtension[kCVImageBufferColorPrimariesKey]
            
            if let colorPrimaries = colorPrimaries {
                var colorSpaceProperties: [String: AnyObject] = [kCVImageBufferColorPrimariesKey as String: colorPrimaries]
                
                if let yCbCrMatrix = inputFormatDescriptionExtension[kCVImageBufferYCbCrMatrixKey] {
                    colorSpaceProperties[kCVImageBufferYCbCrMatrixKey as String] = yCbCrMatrix
                }
                
                if let transferFunction = inputFormatDescriptionExtension[kCVImageBufferTransferFunctionKey] {
                    colorSpaceProperties[kCVImageBufferTransferFunctionKey as String] = transferFunction
                }
                
                pixelBufferAttributes[kCVBufferPropagatedAttachmentsKey as String] = colorSpaceProperties
            }
        }
        
        var outputBuffer: CVPixelBuffer? = nil
        
        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                                   streamWidth, streamHeight,
                                                   Consts.PixelFormat_RGB,
                                                   pixelBufferAttributes as NSDictionary,
                                                   &outputBuffer)
        
        if status == kCVReturnSuccess, let buffer = outputBuffer {
            if bufferIndex >= outputBufferPool.count {
                outputBufferPool.append(buffer)
            } else {
                outputBufferPool[bufferIndex] = buffer
            }
            return buffer
        }
        return nil
    }
    
    func createOutputTexture(from imageBuffer: CVImageBuffer) -> MTLTexture? {
        if  bufferIndex < outputTexurePool.count {
            return outputTexurePool[bufferIndex]
        }
        guard let metal = MetalCore.instance else {
            return nil
        }

        if let texture = metal.makeTexture(from: imageBuffer) {
            if bufferIndex >= outputTexurePool.count {
                outputTexurePool.append(texture)
            } else {
                outputTexurePool[bufferIndex] = texture
            }
            return texture
        }
        return nil
    }

    
}
