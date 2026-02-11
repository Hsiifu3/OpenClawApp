import Foundation

enum GWLog {
    static let logFile = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".openclaw/workspace/OpenClawApp/gateway-debug.log")

    static func log(_ msg: String) {
        let ts = ISO8601DateFormatter().string(from: Date())
        let line = "\(ts) \(msg)\n"
        NSLog("%@", msg)
        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFile.path) {
                if let fh = try? FileHandle(forWritingTo: logFile) {
                    fh.seekToEndOfFile()
                    fh.write(data)
                    fh.closeFile()
                }
            } else {
                try? data.write(to: logFile)
            }
        }
    }
}
