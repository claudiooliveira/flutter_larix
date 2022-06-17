//
//  File.swift
//  
//
//  Created by Denis Slobodskoy on 10.01.2022.
//

import Foundation
import CoreMedia

public class ActiveCameraInfo: NSObject {
    
    init(cameraId: String) {
        if cameraId.contains("built-in_video"), let pos = cameraId.lastIndex(of: ":") {
            let strPos = cameraId.index(after: pos)
            self.cameraId = String(cameraId.suffix(from: strPos))
        } else {
            self.cameraId = cameraId
        }
        super.init()
    }
    
    public var cameraId: String
    public var recordSize: CMVideoDimensions = CMVideoDimensions(width: 0, height: 0)
    public var lensFacing: String = "unknown"
    public var deviceType: String = "wide"
    public var fps: Float64 = 0.0
    public var maxZoom: Float = 1.0
    public var isTorchSupported: Bool = false
    public var physicalCameras: [String] = []
    public var physicalZoomFactors: [Float] = []

}
