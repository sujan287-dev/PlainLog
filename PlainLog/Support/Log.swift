import OSLog

/// Centralized logging via os.log.
/// Analytics and tracking are forbidden by production spec §4.
/// NEVER log user note content.
enum Log {
    private static let subsystem = "com.plainlog.ios"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let folderAccess = Logger(subsystem: subsystem, category: "folder-access")
    static let fileIO = Logger(subsystem: subsystem, category: "file-io")
    static let document = Logger(subsystem: subsystem, category: "document")
    static let parser = Logger(subsystem: subsystem, category: "parser")
    static let billing = Logger(subsystem: subsystem, category: "billing")
    static let export = Logger(subsystem: subsystem, category: "export")
}
