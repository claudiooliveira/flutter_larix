import Foundation
import CoreImage
import UIKit
import LarixSupport

public enum ImageLayerError: Error {
    case badUrl
    case imageLoadFailed
    case urlSessionError(Error)
    case httpError(Int)
    case fileTooLarge(Int64)
    case imageTooLarge(Int, Int)
    case unsupportedType(String)
}

public protocol CompositeImageLayerDelegate {
    func onImageLoadComplete()
    func onImageLoaded(name: String)
    func onLoadError(layer: ImageLayer, error: ImageLayerError)
    func onDownloadFinish(layer: ImageLayer, location: URL, suggestedFilename: String) -> URL?
}

public extension CompositeImageLayerDelegate {
    func onImageLoaded(name: String) {
        
    }
    
    func onLoadError(layer: ImageLayer, error: ImageLayerError) {
        
    }
    
    func onDownloadFinish(layer: ImageLayer, location: URL, suggestedFilename: String) -> URL? {
        return nil
    }
}

extension Date {
    var httpHeaderString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "E, d MMM yyyy HH:mm:ss z"
        formatter.timeZone = TimeZone(identifier: "UTC")
        let str = formatter.string(for: self) ?? ""
        return str
    }
    
    static func fromHttpHeader(_ str: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "E, d MMM yyyy HH:mm:ss z"
        formatter.timeZone = TimeZone(identifier: "UTC")
        if let date = formatter.date(from: str) {
            return date
        }
        return nil

    }
}

public class CompositeImageLayer: NSObject, URLSessionDownloadDelegate, URLSessionDataDelegate {
    let maxAllowedDowloadSize:Int64 = 10_000_000
    let maxAllowedTextSize:Int64 = 50_000
    let maxAllowedImageResolution:Int64 = 10_000_000

    public var delegate: CompositeImageLayerDelegate?
    public var outputImage: CIImage?
    public var size: CGSize = CGSize(width: 1920, height: 1080)
    
    private var layers: [ImageLayer] = []
    private var imageCache: [String: CIImage] = [:]

    private var urlSession: URLSession?
    static private var operationQueue: OperationQueue?
    
    private var pendingImageLoad: Int = 0
    private var imagesLoaded: Int = 0
    private var downloadTasks: [Int: ImageLayer] = [:]
    private var running = true
    
    private var refreshTimer: Timer? = nil
    let templatePattern = "<%.+%>"

    private func initQueue() {
        if Self.operationQueue != nil {
            return
        }
        let newQueue = OperationQueue()
        newQueue.name = "imageDownloader"
        Self.operationQueue = newQueue
    }
    
    public func loadList(_ layerList: [ImageLayer]) {
        initQueue()
        pendingImageLoad = layerList.count
        imagesLoaded = 0
        if layerList.isEmpty {
            clearImages()
        }
        layers.removeAll()
        var scheduleUpdate = false
        for layer in layerList {
            layers.append(layer)
            if layer.type == .image {
                loadImageLayer(layer, scheduleUpdate: &scheduleUpdate)
            } else {
                loadTextLayer(layer, scheduleUpdate: &scheduleUpdate)
            }
        }
        if scheduleUpdate {
            DispatchQueue.main.async {
                self.refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                    self?.checkRefresh()
                }
            }
        }
        
        if (layerList.isEmpty) {
            drawImages()
        }
    }
    
    private func loadImageLayer(_ layer: ImageLayer, scheduleUpdate: inout Bool) {
        let now = Date()

        if let id = layer.cacheTag, let image = imageCache[id] {
            layer.image = image
        }
        var local = layer.image != nil
        if !local, let localUrl = layer.localUrl, FileManager.default.fileExists(atPath: localUrl.path) {
            local = true
        }
        if layer.updateInterval > 0 && layer.remoteUrl != nil {
            if let nextUpdateTime = layer.httpLastModified {
                if nextUpdateTime + TimeInterval(layer.updateInterval) < now {
                    local = false
                }
            } else {
                local = false
            }
        }

        if local {
            openImageAsync(layer: layer)
            return
        }
        guard let url = layer.remoteUrl, url.scheme?.starts(with: "http") == true else {
            delegate?.onLoadError(layer: layer, error: .badUrl)
            markImageLoaded(success: false)
            return
        }
        guard let request = createUrlRequest(layer: layer) else {
            return
        }
        if let task = urlSession?.downloadTask(with: request) {
            let taskId = task.taskIdentifier
            downloadTasks[taskId] = layer
            if layer.updateInterval > 0 {
                layer.lastCheck = now
                scheduleUpdate = true
            }
            task.resume()
        }
    }
    
    private func createUrlSession() {
        if urlSession != nil {
            return
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        urlSession = URLSession(configuration: configuration, delegate: self, delegateQueue: Self.operationQueue)

    }
    
    private func createUrlRequest(layer: ImageLayer) -> URLRequest? {
        createUrlSession()
        guard let url = layer.remoteUrl else {
            return nil
        }
        LogVerbose("Requesting \(url.absoluteString)")
        var canUseCached: Bool = layer.image != nil
        if layer.type == .image, let localUrl = layer.localUrl, FileManager.default.fileExists(atPath: localUrl.path) {
            canUseCached = true
        }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        if canUseCached {
        if let lastUpdate = layer.httpLastModified {
                let IfModifiedSince = lastUpdate.httpHeaderString
                request.setValue(IfModifiedSince, forHTTPHeaderField: "If-Modified-Since")
            }
            if let etag = layer.httpETag {
                request.setValue(etag, forHTTPHeaderField: "If-None-Match")
            }
        }
        return request

    }
    
    private func loadTextLayer(_ layer: ImageLayer, scheduleUpdate: inout Bool) {
        let now = Date()

        if let text = layer.text {
            if layer.updateInterval > 0 && hasTemplate(text: text) {
                layer.lastCheck = now
                scheduleUpdate = true
            }
            drawTextAsync(layer: layer)
            return
        }
        guard let url = layer.remoteUrl, url.scheme?.starts(with: "http") == true else {
            delegate?.onLoadError(layer: layer, error: .badUrl)
            markImageLoaded(success: false)
            return
        }
        layer.resetData()
        guard let request = createUrlRequest(layer: layer),
              let task = urlSession?.dataTask(with: request) else {
            return
        }
        let taskId = task.taskIdentifier
        downloadTasks[taskId] = layer
        if layer.updateInterval > 0 {
            layer.lastCheck = now
            scheduleUpdate = true
        }
        task.resume()
    }
        
    public func checkRefresh() {
        guard running else {
            return
        }
        pendingImageLoad = 0
        let now = Date()
        for layer in layers {
            guard let checkTime = layer.lastCheck else {
                continue
            }
            if layer.updateInterval <= 0 || checkTime + TimeInterval(layer.updateInterval - 0.1) > now {
                continue
            }
            if layer.type == .text && layer.text?.isEmpty == false {
                pendingImageLoad += 1
                layer.lastCheck = now
                drawTextAsync(layer: layer)
                continue
            }
            guard let url = layer.remoteUrl, url.scheme?.starts(with: "http") == true else {
                continue
            }
            
            if downloadTasks.contains(where: { (_, value) in
                value.remoteUrl == layer.remoteUrl
            }) {
                //Already queued
                continue
            }
            
            guard let request = createUrlRequest(layer: layer) else {
                continue
            }
            
            var task: URLSessionTask?
            if layer.type == .image {
                task = urlSession?.downloadTask(with: request)
            } else {
                task = urlSession?.dataTask(with: request)
            }
            if let task = task {
                layer.lastCheck = now
                let taskId = task.taskIdentifier
                downloadTasks[taskId] = layer
                task.resume()
                pendingImageLoad += 1
            }
        }
    }
    
    
    public func invalidate() {
        LogInfo("invalidate statr")
        running = false
        outputImage = nil
        refreshTimer?.invalidate()
        refreshTimer = nil
        urlSession?.invalidateAndCancel()
        Self.operationQueue?.cancelAllOperations()
        imageCache.removeAll()
        layers.removeAll()
        LogInfo("invalidate end")
    }
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                           completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        let taskId = dataTask.taskIdentifier
        guard let layer = downloadTasks[taskId] else {
            NSLog("Something wrong been downloaded")
            completionHandler(.cancel)
            return
        }
        guard let response = dataTask.response as? HTTPURLResponse else {
            completionHandler(.cancel)
            return
        }
        var error: ImageLayerError?
        let useCached = checkHttpHeaders(task: dataTask, layer: layer)
        if useCached && layer.image != nil {
            markImageLoaded(success: false)
            completionHandler(.cancel)
        }

        let statusCode = response.statusCode
        if statusCode != 200 {
            error = .httpError(statusCode)
        }

        if error == nil, let mimeType = response.mimeType {
            if !mimeType.starts(with: "text/") && !mimeType.contains("/json") {
                error = .unsupportedType(mimeType)
            }
        }
        let size = response.expectedContentLength
        if error == nil, size > maxAllowedTextSize {
            error = .fileTooLarge(size)
        }
        
        if let error = error {
            completionHandler(.cancel)
            downloadTasks.removeValue(forKey: taskId)
            delegate?.onLoadError(layer: layer, error: error)
            markImageLoaded(success: false)
            return
        }
        completionHandler(.allow)
        
    }
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        let taskId = dataTask.taskIdentifier
        guard let layer = downloadTasks[taskId] else {
            NSLog("Something wrong been downloaded")
            return
        }
        layer.appendData(data: data)
    }
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let taskId = downloadTask.taskIdentifier
        guard let layer = downloadTasks[taskId] else {
            NSLog("Something wrong been downloaded")
            return
        }
        var httpCode: Int = 200
        var useCached = false
        if let httpRes = downloadTask.response as? HTTPURLResponse {
            httpCode = httpRes.statusCode
            useCached = checkHttpHeaders(task: downloadTask, layer: layer)
        }
        defer {
            downloadTasks.removeValue(forKey: taskId)
        }

        if useCached || httpCode == 304 {
            if layer.image != nil {
                LogInfo("Use previous image ")
                markImageLoaded(success: false)
            } else {
                openImageAsync(layer: layer)
            }
            return
        }
        if httpCode < 200 || httpCode > 299 {
            LarixLogger.put(message: "File downloading status \(httpCode)", severity: .error, priority: .med)
            delegate?.onLoadError(layer: layer, error: .httpError(httpCode))
            markImageLoaded(success: false)
            return
        }
        
        let fileName = downloadTask.response?.suggestedFilename ?? UUID().uuidString
        if let dest = delegate?.onDownloadFinish(layer: layer, location: location, suggestedFilename: fileName) {
            layer.localUrl = dest
            openImageAsync(layer: layer)
        } else {
            let renameTo = location.deletingLastPathComponent().appendingPathComponent(fileName)
            do {
                try FileManager.default.moveItem(at: location, to: renameTo)
                layer.localUrl = renameTo
                openImageAsync(layer: layer, isTempFile: true)
            } catch {
                delegate?.onLoadError(layer: layer, error: .imageLoadFailed)
                markImageLoaded(success: false)
            }
        }
    }
    
    private func checkHttpHeaders(task: URLSessionTask, layer: ImageLayer) -> Bool {
        guard let httpRes = task.response as? HTTPURLResponse else {
            return false
        }
        var lastModStr: String?
        var etag: String?
        
        if #available(iOS 13.0, *) {
            lastModStr = httpRes.value(forHTTPHeaderField: "Last-Modified")
            etag = httpRes.value(forHTTPHeaderField: "Etag")
        } else {
            let fields = httpRes.allHeaderFields
            lastModStr = fields["Last-Modified"] as? String
            etag = fields["Etag"]  as? String
        }
        var useCached = false
        if let lastModStr = lastModStr,
            let lastMod = Date.fromHttpHeader(lastModStr) {
            LogInfo("Last-Modified: \(lastModStr)")
            if let prevValue = layer.httpLastModified, lastMod.timeIntervalSince(prevValue) < 1.0 {
                useCached = true
            }
            layer.httpLastModified = lastMod
        } else {
            layer.httpLastModified = nil
        }
        if let etag = etag {
            LogInfo("Etag: \(etag)")
            if let prevValue = layer.httpETag, etag == prevValue {
                useCached = true
            }
            layer.httpETag = etag
        } else {
            layer.httpETag = nil
        }
        return useCached

        
    }
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let taskId = downloadTask.taskIdentifier
        guard let layer = downloadTasks[taskId] else {
            return
        }

        let totalSize: Int64
        if totalBytesExpectedToWrite == NSURLSessionTransferSizeUnknown {
            totalSize = bytesWritten
        } else {
            totalSize = totalBytesExpectedToWrite
        }
        var error: ImageLayerError?

        if totalSize > maxAllowedDowloadSize {
            error = .fileTooLarge(totalSize)
        } else if let mimeType = downloadTask.response?.mimeType {
            if !mimeType.starts(with: "image/") {
                error = .unsupportedType(mimeType)
            }
        }
        if let message = error {
            downloadTask.cancel()
            layer.updateInterval = -1
            downloadTasks.removeValue(forKey: taskId)
            delegate?.onLoadError(layer: layer, error: message)
            markImageLoaded(success: false)
        }
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let taskId = task.taskIdentifier
        guard let layer = downloadTasks[taskId] else {
            return
        }

        if let error = error {
            let name = layer.name
            layer.updateInterval = -1
            LarixLogger.put(message: "Request of \(name) completed with error: \(error.localizedDescription)", severity: .error, priority: .med)
            delegate?.onLoadError(layer: layer, error: .urlSessionError(error))
            markImageLoaded(success: false)
            downloadTasks.removeValue(forKey: taskId)
            return
        }
        if layer.type == .text,  let data = layer.getData() {
            drawTextAsync(layer: layer, htmlData: data)
            downloadTasks.removeValue(forKey: taskId)
            layer.resetData()
            return
        }

    }

    private func openImageAsync(layer: ImageLayer, isTempFile: Bool = false) {
        guard let queue = Self.operationQueue else {
            LogError("No overlay loading queue")
            self.markImageLoaded(success: false)
            return

        }
        let id = layer.cacheTag ?? "(null)"
        LogInfo("openImageAsync \(id)")

        queue.addOperation { [weak self] in
            var isLoaded = false
            if let image = self?.openImage(layer: layer, isTempFile: isTempFile) {
                layer.image = image
                layer.rect = self?.computeRect(layer: layer) ?? CGRect()
                isLoaded = true
                self?.delegate?.onImageLoaded(name: layer.name)
            }
            self?.markImageLoaded(success: isLoaded)
        }
    }
    
    private func openImage(layer: ImageLayer, isTempFile: Bool = false) -> CIImage? {
//        if layer.image != nil {
//            return layer.image
//        }
        var image: CIImage? = nil
        if let url = layer.localUrl {
           image = CIImage(contentsOf: url)
        }
        if image == nil || image?.extent.isEmpty != false {
            self.delegate?.onLoadError(layer: layer, error: .imageLoadFailed)
            image = nil
        }

        if isTempFile, let path = layer.localUrl {
            try? FileManager.default.removeItem(at: path)
        }
        

        return image
    }
    
    private func drawTextAsync(layer: ImageLayer, htmlData: Data? = nil) {
        guard let queue = Self.operationQueue else {
            LogError("No overlay loading queue")
            self.markImageLoaded(success: false)
            return

        }
        queue.addOperation { [weak self] in
            var isLoaded = false
            defer {
                self?.markImageLoaded(success: isLoaded)
            }
            var dataOpt = htmlData
            if htmlData == nil {
                guard let origin = layer.text, let text = self?.parseTags(text: origin) else {
                    return
                }
                dataOpt = Data(text.utf8)
            }
            guard let data = dataOpt, let image = self?.imageFromText(data) else {
                return
            }
            layer.image = image
            layer.rect = self?.computeRect(layer: layer) ?? CGRect()
            isLoaded = true
            self?.delegate?.onImageLoaded(name: layer.name)
        }
    }
    
    func hasTemplate(text: String) -> Bool {
        let pos = text.range(of: templatePattern, options: .regularExpression)
        return pos != nil

    }
    
    func parseTags(text: String) -> String {
        do {
            let regex = try NSRegularExpression(pattern: templatePattern, options: [.allowCommentsAndWhitespace])
            let fullRange = NSRange(text.startIndex..<text.endIndex,in: text)
            if regex.firstMatch(in: text, range: fullRange) == nil {
                return text
            }
            var result: String = ""
            var prevIndex: String.Index? = nil
            regex.enumerateMatches(in: text, range: fullRange) { (match, flags, stop) in
                guard let wtf = match?.range, let range = Range(wtf, in: text) else {
                    return
                }
                if let prev = prevIndex {
                    let prefix = text[prev..<range.lowerBound]
                    result.append(contentsOf: prefix)

                } else {
                    let prefix = text[..<range.lowerBound]
                    result.append(contentsOf: prefix)
                }
                prevIndex = range.upperBound
                let substr = String(text[range])
                let eval = evaluate(substr)
                result += eval
            }
            if let prevIndex = prevIndex {
                let suffix = text[prevIndex..<text.endIndex]
                result += suffix
            }
            return result
        } catch {
            LogError("Error parsing tamplate: \(error.localizedDescription)")
            return text
        }
    }

    func evaluate(_ str: String) -> String {
        if let pos = str.range(of: "date(", options: [.caseInsensitive]) {
            let rawArgs = parseParameters(str, startIndex: pos.upperBound)
            let args = dropQuotes(rawArgs)
            let arg0 = args.count > 0 ? args[0] : ""
            let arg1 = args.count > 1 ? args[1] : ""
            let arg2 = args.count > 2 ? args[2] : ""

            //LogInfo("date parameter: \(arg0) \(arg1)")
            let now = Date()
            let fmt = DateFormatter()
            if arg0.isEmpty {
                fmt.dateStyle = .short
                fmt.timeStyle = .medium
            } else {
                fmt.dateFormat = arg0
            }
            if !arg1.isEmpty {
                let locale = Locale(identifier: arg1)
                fmt.locale = locale
            }
            if !arg2.isEmpty, let tz = TimeZone(identifier: arg2) {
                fmt.timeZone = tz
            }
            return fmt.string(from: now)

        }
        return ""
    }
    
    func parseParameters(_ str: String, startIndex: String.Index) -> [Substring] {
        var bracketCount:Int = 1
        var endIndex: String.Index? = nil
        let braceRange = startIndex..<str.endIndex
        let substr = str[braceRange]
        //LogVerbose("template: \(substr)")
        var quote: Character? = nil
        var commaPos: [String.Index] = []
        var prevIndex = str.index(startIndex, offsetBy: -1, limitedBy: str.endIndex)
    enumeration: for (idx,ch) in substr.enumerated() {
            //LogVerbose("\(idx): \(ch)")
            if let q = quote {
                if ch == q {
                    quote = nil
                }
                //Skip quoted text
                continue
            }

            switch ch {
            case "'", "\"":
                quote = ch
            case  "“":
               quote =  "”"
            case  "‘":
               quote =  "’"
            case "«":
                quote =  "»"
            case "„":
                quote =  "“"
            case ",":
                if let pos = str.index(substr.startIndex, offsetBy: idx, limitedBy: str.endIndex) {
                    commaPos.append(pos)
                }
            case "(":
                bracketCount += 1
            case ")":
                bracketCount -= 1
                if bracketCount == 0 {
                    endIndex = str.index(substr.startIndex, offsetBy: idx, limitedBy: str.endIndex)
                    if let i = endIndex {
                        commaPos.append(i)
                    }

                    break enumeration
                }
            default:
                continue
            }
        }
     
        let args: [Substring] = commaPos.compactMap { pos in
            guard let prev = prevIndex, let first = str.index(prev, offsetBy: 1, limitedBy: str.endIndex) else {
                return nil
            }
            prevIndex = pos
            return str[first..<pos]
        }
        return args
    }
    
    func dropQuotes(_ params: [Substring]) -> [String] {
        let res: [String] = params.map { sub in
            var str = String(sub).trimmingCharacters(in: .whitespacesAndNewlines)
            if (str.first == "'" && str.last == "'") || (str.first == "\"" && str.last == "\"") ||
                (str.first == "‘" && str.last == "’") || (str.first == "“" && str.last == "”")
            {
                str.removeFirst()
                str.removeLast()
            }
            return str
        }
        return res
    }

    func imageFromText(_ htmlData: Data) -> CIImage? {
        let strOptions: [NSAttributedString.DocumentReadingOptionKey:Any] = [.documentType: NSAttributedString.DocumentType.html, .characterEncoding: String.Encoding.utf8.rawValue]
        guard let attributedString = try? NSAttributedString(data: htmlData, options: strOptions, documentAttributes: nil) else {
            return nil
        }

        guard let textFilter = CIFilter(name: "CIAttributedTextImageGenerator") else {
            return nil
        }
        textFilter.setValue(attributedString, forKey: "inputText")
        textFilter.setValue(2.0, forKey: "inputScaleFactor")
        return textFilter.outputImage
    }
    
    private func computeRect(layer: ImageLayer) -> CGRect {
        if layer.rect.width > 0 && layer.rect.height > 0 {
            return layer.rect
        }
        guard let image = layer.image else {
            return CGRect.zero
        }
        let imageSize = image.extent.size
        var w = imageSize.width
        var h = imageSize.height
        let canvasSize = self.size
        let canvasAspect = canvasSize.width / canvasSize.height
        if layer.scale != 0 {
            let fullW: CGFloat
            let fullH: CGFloat
            if canvasAspect > w / h {
                fullW = canvasSize.width
                fullH = canvasSize.width * h / w
            } else {
                fullW = canvasSize.height * w / h
                fullH = canvasSize.height
            }
            w = fullW * layer.scale
            h = fullH * layer.scale
        }
        let xPadding = canvasSize.width - w
        let yPadding = canvasSize.height - h
        let xPos = layer.center.x * xPadding
        let yPos = layer.center.y * yPadding
        return CGRect(x: xPos, y: yPos, width: w, height: h)
    }
    
    private func markImageLoaded(success: Bool = true) {
        //LogInfo("markImageLoaded: \(pendingImageLoad) left")
        if pendingImageLoad <= 0 {
            return
        }
        if success {
            imagesLoaded += 1
        }
        pendingImageLoad -= 1
        if pendingImageLoad == 0 && imagesLoaded > 0 {
            drawImages()
        }
    }
    
    
    func clearImages() {
        outputImage = nil
    }
    
    func drawImages() {
        if !running {
            return
        }
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        let orderedLayers = layers.sorted()
        var updated = false
        for layer in orderedLayers where layer.active {
            if let image = layer.image {
                if let id = layer.cacheTag, imageCache[id] == nil {
                   imageCache[id] = image
                }

                let uiImage = UIImage(ciImage: image)
                if layer.opacity > 0.991 {
                    uiImage.draw(in: layer.rect)
                } else {
                    uiImage.draw(in: layer.rect, blendMode: .normal, alpha: layer.opacity)
                }
                updated = true
            }
        }
        
        if updated,
           let uiImage = UIGraphicsGetImageFromCurrentImageContext(),
           let ciImage = CIImage(image: uiImage) {
            outputImage = ciImage
        } else {
            outputImage = nil
        }
        UIGraphicsEndImageContext()
        delegate?.onImageLoadComplete()
    }

    
}
