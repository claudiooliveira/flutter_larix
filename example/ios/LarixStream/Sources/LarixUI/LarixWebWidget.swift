import Foundation
import UIKit
import WebKit
import LarixSupport

 /**
  https://www.hackingwithswift.com/articles/112/the-ultimate-guide-to-wkwebview
  
  */
public class LarixWebWidget: UIView {
    
    public internal(set) var config: WebWidgetConfig
    public var hasImage: Bool {
        return config.mode != .previewOnly
    }

    internal var outputImage: CIImage? = nil

    internal var parent: UIView?
    internal var page: WKWebView
    internal var request: URLRequest?
    internal var loadObserver: NSKeyValueObservation?
    internal var takingSnaphot = false
    internal var snapshotConfig = WKSnapshotConfiguration()
    internal var active = false
    internal var contentController: WKUserContentController
    
    internal var lock = NSLock()
    
    private var refreshTimer: Timer? = nil
    var maxFrameRate: Double = 4.0
    private var startTime: Date = Date()
    
    func getCssScript(style: String) -> String {
        let myScript = """
        var content = `\(style)`;
        var style = document.createElement('style');
        style.innerHTML = content;
        document.getElementsByTagName('head')[0].appendChild(style);
        """
        return myScript

    }
    
    func getCssLinkScript(url: String) -> String {
        let myScript = """
        var link = document.createElement('link');
        link.rel = 'stylesheet';
        link.type = 'text/css';
        link.href = '\(url)';
        document.getElementsByTagName('head')[0].appendChild(link);
        """
        return myScript

    }
        
    public init(parent: UIView, config: WebWidgetConfig) {
        let rect = parent.frame
        let pageFrame = Self.getFrame(frame: rect, config: config)
        
        contentController = WKUserContentController()

        let configuration = WKWebViewConfiguration()
        if #available(iOS 13.0, *) {
            configuration.defaultWebpagePreferences.preferredContentMode = .mobile
        }
        configuration.userContentController = contentController
        page = WKWebView(frame: pageFrame, configuration: configuration)
        self.config = config
        self.parent = parent
        super.init(frame: rect)

        setupPage()
    }
    
    public func withOutputImage( _ block: @escaping (CIImage) -> Void) {
        lock.lock()
        if let image = outputImage, image.extent != CGRect.zero {
            block(image)
        }
        lock.unlock()
    }
    
    static private func getFrame(frame: CGRect, config: WebWidgetConfig) -> CGRect {
        let w = frame.width * CGFloat(config.scaleX)
        let h = frame.height * CGFloat(config.scaleY)
        let left: CGFloat = (frame.width - w) * CGFloat(config.posX)
        let top: CGFloat = (frame.height - h) * CGFloat(config.posY)
        LogInfo("frame \(frame.width)x\(frame.height)")
        LogInfo("WebView pos (\(left),\(top)) size \(w)*\(h)")
        return CGRect(x: left, y: top, width: w, height: h)
    }
    
    private func setupPage() {
        self.isOpaque = false
        self.backgroundColor = UIColor.clear
        page.isOpaque = false
        page.backgroundColor = UIColor.clear
        page.scrollView.backgroundColor = UIColor.clear
        insertSubview(page, at: 0)
        isHidden = config.mode == .streamOnly
        
        setSnapsotWidth()
        if #available(iOS 13.0, *) {
            snapshotConfig.afterScreenUpdates = false
        }

    }
    
    func setSnapsotWidth() {
        let viewH = page.bounds.height
        let viewW = page.bounds.width
        let scale = UIScreen.main.scale
        let streamW = config.streamSize.width / scale
        let streamH = config.streamSize.height / scale
        var width = streamW * CGFloat(config.scaleX)
        let videoHeight = viewH * streamW / viewW
        if videoHeight > config.streamSize.height {
            let ratio = streamH / viewH
            width = viewW * ratio
        }
        snapshotConfig.snapshotWidth = NSNumber(floatLiteral: width)

    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        if let parent = parent {
            frame = parent.frame
            let webFrame = Self.getFrame(frame: parent.frame, config: self.config)
            page.frame = webFrame
            setSnapsotWidth()
        }
    }
    
    public func load() {
        stop()
        guard let url = config.url else {
            return
        }
        contentController.removeAllUserScripts()
        if let css = config.css, css.isEmpty == false, config.cssType != .none {
            let myScript = config.cssType == .text ? getCssScript(style: css) : getCssLinkScript(url: css)
            let userScript = WKUserScript(
                source: myScript,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            )
            contentController.addUserScript(userScript)
        }
        if #available(iOS 14.0, *) {
            page.pageZoom = config.zoom
        }
        active = true
        let request = URLRequest(url: url)
        self.request = request
        page.load(request)
        loadObserver = page.observe(\.isLoading, options: .new) { (_, change) in
            let isLoading = change.newValue ?? false
            
            self.onLoaded(!isLoading)
        }
    }
    
    public func stop() {
        lock.lock()
        active = false
        refreshTimer?.invalidate()
        self.refreshTimer = nil
        page.stopLoading()
        request = nil
        outputImage = nil
        lock.unlock()
    }
    
    public func setConfig(_ config: WebWidgetConfig?) {
        stop()
        if let config = config {
            self.config = config
            setNeedsLayout()
            load()
        }
    }
    
    override public func removeFromSuperview() {
        super.removeFromSuperview()
        page.removeFromSuperview()
        stop()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func onLoaded(_ loaded: Bool) {
        LogInfo("Page loaded")
        if request == nil || config.mode == .previewOnly {
            return
        }
        if loaded {
            startTimer()
        } else {
            refreshTimer?.invalidate()
            refreshTimer = nil
        }
    }
    
    private func takePicture() {
        guard active == true && takingSnaphot == false && config.mode != .previewOnly else {
            return
        }
        snapshotConfig.rect = page.bounds
        takingSnaphot = true
        
        DispatchQueue.main.async {
            //LogVerbose("Taking snapshot \(snapshotConfig.rect.debugDescription) ")
            self.startTime = Date()
            self.page.takeSnapshot(with: self.snapshotConfig) { image, error in
                if let image = image {
                    self.generateSnapshot(image: image)
                    //self.startTimer()
                }
                self.takingSnaphot = false
            }
        }
    }
    
    private func generateSnapshot(image: UIImage) {
        if active == false {
            self.refreshTimer?.invalidate()
            self.refreshTimer = nil
            return
        }
        if !lock.try() {
            return
        }
        defer {
            lock.unlock()
        }
        guard let origin = CIImage(image: image) else {
            return
        }
        let w = origin.extent.width
        let h = origin.extent.height
        let l = (config.streamSize.width - w) * CGFloat(config.posX)
        let b = (config.streamSize.height - h) * CGFloat(1-config.posY)
        if l > 0 || b > 0 {
            let transform = CGAffineTransform.init(translationX: l, y: b)
            self.outputImage = origin.transformed(by: transform)
        } else {
            self.outputImage = origin
        }
//        let now = Date()
//        let interval = now.timeIntervalSince(self.startTime)
//        let durationMs = Double(interval) * 1000
//        if let size = self.outputImage?.extent.size {
//            LogVerbose("Got image \(size.width)x\(size.height) in \(durationMs) ms")
//        }

    }
    
    private func startTimer() {
        if active == false || refreshTimer != nil {
            return
        }
        DispatchQueue.main.async {
            let interval = 1.0 / self.maxFrameRate
            self.refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                self?.takePicture()
            }
        }
    }
 

}
