
import Foundation
import MetalKit
import LarixSupport

struct RotateParameters
{
    // Coefficients for sample function:
    // Xsrc = Xdest * scale[0][0] + Ydest * scale[0][1] + offset[0]
    // Ysrc = Xdest * scale[1][0] + Ydest * scale[1][1] + offset[1]
    var scaleM: matrix_float2x2
    var offsetM: vector_float2
    
    init(transform: CGAffineTransform) {
        /*  sample() function in shader is opposite to normal transform:
            we specify source coordinates to be mapped to specific texture position [posIn = ƒ(posOut)]
            while normal affine transform is map source position to output [posOut = ƒ(posIn].
            Due to this, we must invert affine transform matrix:
            Input: Q = A * P + B, where P is source position, A is 2x2 scale matrix, B is 2x1 offset matrix
            Output: P = A‘ * Q - A‘ * B, where A‘ is inverse of A (A * A‘ = |1|)
        */
        let det = transform.a * transform.d - transform.b * transform.c
        scaleM = matrix_float2x2([Float(transform.d/det), Float(-transform.c/det)],
                                 [Float(-transform.b/det), Float(transform.a/det)])
        let tx = Float(-transform.tx) * scaleM[0][0] + Float(-transform.ty) * scaleM[0][1]
        let ty = Float(-transform.tx) * scaleM[1][0] + Float(-transform.ty) * scaleM[1][1]
        offsetM = vector_float2(tx, ty)
    }
}

struct RotateParametersDual
{
    var mainRect: vector_int4
    var pipRect: vector_int4
    var mainTransform: RotateParameters
    var pipTransform: RotateParameters
}

class MetalCore {
    
    static var instance: MetalCore? {
        return theInstance
    }
    
    var videoSize: CGSize = CGSize(width: 1920, height: 1080)

    private var device: MTLDevice?
    private var metalTextureCache: CVMetalTextureCache?
    private var pipelineState: MTLComputePipelineState?
    private var commandQueue: MTLCommandQueue?
    private var textureLoader: MTKTextureLoader?
    
    static private var theInstance: MetalCore?

    static func startup(dual: Bool = false) {
        if theInstance == nil {
            theInstance = MetalCore(dual: dual)
        }
    }
    
    static func shutdown() {
        theInstance = nil
    }

    
    init(dual: Bool) {
        device = MTLCreateSystemDefaultDevice()
        guard let device = device else {
            LogError("Failed to create Metal device")
            return
        }
        commandQueue = device.makeCommandQueue()

        guard let defaultLibrary = try? device.makeDefaultLibrary(bundle: Bundle.module) else {
            LogError("Failed to load metal file")
            return
        }
        let mainFunction = dual ? "rotateMixDualShader" : "rotateMixShader"
        guard let scaleFunction = defaultLibrary.makeFunction(name: mainFunction) else {
            return
        }
    
        do {
            pipelineState = try device.makeComputePipelineState(function: scaleFunction)
        } catch {
            LogError("Could not create compute pipeline state: \(error)")
        }

        if CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &metalTextureCache) != kCVReturnSuccess {
            LogError("Unable to allocate video mixer texture cache")
        }
        textureLoader = MTKTextureLoader(device: device)

    }
    
    func makeTexture(from imageBuffer: CVImageBuffer) -> MTLTexture? {
        guard let cache = metalTextureCache else {
            LogError("No texture cache")
            return nil
        }
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)

        var cvTextureOut: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                  cache,
                                                  imageBuffer,
                                                  nil,
                                                  .bgra8Unorm,
                                                  width,
                                                  height,
                                                  0,
                                                  &cvTextureOut)


        guard let cvTexture = cvTextureOut, let texture = CVMetalTextureGetTexture(cvTexture) else {
            LogError("Failed to allocate texture")
            CVMetalTextureCacheFlush(cache, 0)
            return nil
        }
        return texture
    }
    
    func imageToTexture(_ image: CIImage) -> MTLTexture? {
        guard let loader = textureLoader,
              let cgImage = image.cgImage else {
            return nil
        }
        var texture: MTLTexture?
        do {
         try texture = loader.newTexture(cgImage: cgImage)
        } catch {
            LogError("Failed to create texture from overlay")
        }
        return texture

    }
    
    func rotateAndEncode(source: MTLTexture,
                         overlay: MTLTexture?,
                         output: MTLTexture,
                         transform: CGAffineTransform,
                         _ block: @escaping MTLCommandBufferHandler) {
        guard let commandBuffer = commandQueue?.makeCommandBuffer(),
              let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            LogError("failed to get commandBuffer")
            return
        }
        commandEncoder.setComputePipelineState(pipelineState!)
        commandEncoder.setTexture(source, index: 0)
        commandEncoder.setTexture(overlay, index: 1)
        commandEncoder.setTexture(output, index: 2)
        setupVertices(encoder: commandEncoder, transform: transform)

        commandBuffer.addCompletedHandler(block)
        
        let width = pipelineState!.threadExecutionWidth
        let height = pipelineState!.maxTotalThreadsPerThreadgroup / width
        let threadsPerThreadgroup = MTLSizeMake(width, height, 1)
        let imgWidth = Int(videoSize.width)
        let imgHeight = Int(videoSize.height)

        let threadgroupsPerGrid = MTLSize(width: (imgWidth + width - 1) / width,
                                          height: (imgHeight + height - 1) / height,
                                          depth: 1)
            commandEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
            
            commandEncoder.endEncoding()
            commandBuffer.commit()
    }
    
    private func setupVertices(encoder: MTLComputeCommandEncoder, transform: CGAffineTransform) {
        var data = RotateParameters(transform: transform)
        encoder.setBytes(&data, length: MemoryLayout<RotateParameters>.stride, index: 0)
    }
    
    func rotateAndEncodeDual(main: MTLTexture,
                             pip: MTLTexture,
                             overlay: MTLTexture?,
                             output: MTLTexture,
                             mainTransform: CGAffineTransform,
                             pipTransform: CGAffineTransform,
                             _ block: @escaping MTLCommandBufferHandler) {
        guard let commandBuffer = commandQueue?.makeCommandBuffer(),
              let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            LogError("failed to get commandBuffer")
            return
        }
        let sourceSize = CGSize(width: main.width, height: main.height)

        commandEncoder.setComputePipelineState(pipelineState!)
        commandEncoder.setTexture(main, index: 0)
        commandEncoder.setTexture(pip, index: 1)
        commandEncoder.setTexture(overlay, index: 2)
        commandEncoder.setTexture(output, index: 3)
        setupVerticesDual(encoder: commandEncoder, mainTransform: mainTransform, pipTransform: pipTransform, originSize: sourceSize)

        commandBuffer.addCompletedHandler(block)

        let width = pipelineState!.threadExecutionWidth
        let height = pipelineState!.maxTotalThreadsPerThreadgroup / width
        let threadsPerThreadgroup = MTLSizeMake(width, height, 1)
        let imgWidth = Int(videoSize.width)
        let imgHeight = Int(videoSize.height)

        let threadgroupsPerGrid = MTLSize(width: (imgWidth + width - 1) / width,
                                          height: (imgHeight + height - 1) / height,
                                          depth: 1)
            commandEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)

            commandEncoder.endEncoding()
            commandBuffer.commit()
    }

    private func setupVerticesDual(encoder: MTLComputeCommandEncoder,
                                   mainTransform: CGAffineTransform,
                                   pipTransform: CGAffineTransform,
                                   originSize: CGSize) {
        
        let matrixMain = RotateParameters(transform: mainTransform)
        let matrixPip = RotateParameters(transform: pipTransform)
        let mainRect = CGRect(origin: CGPoint.zero, size: originSize).applying(mainTransform)
        let pipRect =  CGRect(origin: CGPoint.zero, size: originSize).applying(pipTransform)
        
        let mainQuad = vector_int4(Int32(mainRect.minX), Int32(mainRect.minY), Int32(mainRect.maxX), Int32(mainRect.maxY))
        let pipQuad = vector_int4(Int32(pipRect.minX), Int32(pipRect.minY), Int32(pipRect.maxX), Int32(pipRect.maxY))

        var data =  RotateParametersDual(mainRect: mainQuad, pipRect: pipQuad, mainTransform: matrixMain, pipTransform: matrixPip)
                
        encoder.setBytes(&data, length: MemoryLayout<RotateParametersDual>.stride, index: 0)
    }
    
}
