import Foundation
import CoreImage


public enum ImageLayerType: Int {
    case image = 0
    case text = 1
}

public class ImageLayer: Comparable {
    public var active: Bool
    public var name: String
    public var type: ImageLayerType = .image
    public var text: String?
    public var remoteUrl: URL?
    public var localUrl: URL?
    public var rect: CGRect = CGRect()
    public var center: CGPoint = CGPoint()
    public var scale: CGFloat = 0.0
    public var opacity: CGFloat = 0.0
    public var zIndex: Int32 = 0
    public var image: CIImage?
    public var cacheTag: String? //If assigned, will keep image by tag in memory cache
    public var updateInterval: Double = 0.0
    public var lastCheck: Date?
    public var httpLastModified: Date?
    public var httpETag: String?
    internal var data: Data?

    public init(name: String, remoteUrl: URL?) {
        self.name = name
        self.remoteUrl = remoteUrl
        self.active = true
    }
    
    public static func < (a: ImageLayer, b: ImageLayer) -> Bool {
        return a.zIndex < b.zIndex
    }

    public static func == (a: ImageLayer, b: ImageLayer) -> Bool {
        return a.zIndex == b.zIndex
    }

    func resetData() {
        data = nil
    }
    
    func appendData(data: Data) {
        if self.data == nil {
            self.data = data
        } else {
            self.data?.append(data)
        }
    }
    
    func getData() -> Data? {
        return data
    }
    

}
