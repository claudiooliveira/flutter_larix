import Foundation

public protocol LarixLoggerDelegate {
    func logEvent(message: String, severity: LarixLogger.Severity, priority: LarixLogger.Priority)
}

public class LarixLogger {
    public static var delegate: LarixLoggerDelegate?

    public enum Severity {
        case verbose
        case info
        case warn
        case error
    }

    public enum Priority {
        case low
        case med
        case high
    }

    public static func put(message: String, severity: Severity  = .info, priority: Priority = .low) {
        if let delegate = Self.delegate {
            delegate.logEvent(message: message, severity: severity, priority: priority)
        } else {
            switch severity {
            case .verbose:
                NSLog("V %@", message)
            case .info:
                NSLog("I %@", message)
            case .warn:
                NSLog("W %@", message)
            case .error:
                NSLog("E %@", message)
            }
        }
    }
}

public func LogError(_ s: String) {
    LarixLogger.put(message: s, severity: .error)
}

public func LogWarn(_ s: String) {
    LarixLogger.put(message: s, severity: .warn)
}

public func LogInfo(_ s: String) {
    LarixLogger.put(message: s, severity: .info)
}


public func LogVerbose(_ s: String) {
    LarixLogger.put(message: s, severity: .verbose)
}
