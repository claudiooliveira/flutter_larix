import Foundation
import CoreVideo

public enum WebWidgetViewMode: String, CustomStringConvertible {
    case previewOnly = "Preview"
    case streamOnly = "Stream"
    case streamAndPreview = "Preview and stream"

    public var description : String { return NSLocalizedString(rawValue, comment: "") }
    
    public static let allValues = [streamAndPreview, previewOnly, streamOnly, ]
    public init(fromInt val: Int32) {
        self = val >= 0 && val < Self.allValues.count ? Self.allValues[Int(val)] : .streamAndPreview
    }
    public var intValue: Int32 {
        return Int32(Self.allValues.firstIndex(of: self) ?? 0)
    }
}

public enum WebWidgetStyleSheetType: Int32 {
    case none = 0
    case link = 1
    case text = 2
}

public struct WebWidgetConfig: Equatable {
    public var url: URL? = nil
    public var streamSize: CGSize = CGSize(width: 1920, height: 1080)
    public var mode: WebWidgetViewMode = .streamAndPreview
    public var cssType: WebWidgetStyleSheetType
    public var css: String?
    public var scaleX: Float = 1.0
    public var scaleY: Float = 1.0
    public var posX: Float = 0.5
    public var posY: Float = 0.5
    public var zoom: Double = 1.0
    
    public init(url: URL? = nil,
                streamSize: CGSize = CGSize(width: 1920, height: 1080),
                mode: WebWidgetViewMode = .streamAndPreview,
                scaleX: Float = 1.0, scaleY: Float = 1.0,
                posX: Float = 0.5, posY: Float = 0.5,
                camScaleX: Float = 1.0, camScaleY: Float = 1.0,
                camPosX: Float = 0.5, camPosY: Float = 0.5,
                cssType: Int32 = 0, css: String? = nil,
                zoom: Double = 1.0) {
        self.url = url
        self.streamSize = streamSize
        self.mode = mode
        self.scaleX = scaleX
        self.scaleY = scaleY
        self.posX = posX
        self.posY = posY
        self.cssType = WebWidgetStyleSheetType(rawValue: cssType) ?? .none
        self.css = css
        self.zoom = zoom
    }
    
}
