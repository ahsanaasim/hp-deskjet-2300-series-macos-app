import Foundation

struct ScannerDevice: Identifiable, Hashable {
    var uri: String
    var label: String
    var id: String { uri }
}

struct CommandResult {
    var status: Int32
    var stdout: String
    var stderr: String
}

/// `hp-scan -L` prints the device, then calls `sane_hpaio_exit()` before
/// checking the device pointer. That frees the list, so a successful listing
/// still exits 1. Treat a parsed device line as success.
enum HPScanCLI {
    static let candidates = [
        "/Library/Printers/hplip/hp-scan",
        "/usr/local/bin/hp-scan",
    ]

    static func locate() -> String? {
        candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    static func parseDevices(_ stdout: String) -> [ScannerDevice] {
        stdout.split(separator: "\n").compactMap { raw in
            let line = String(raw).trimmingCharacters(in: .whitespacesAndNewlines)
            guard let open = line.lastIndex(of: "("),
                  let close = line.lastIndex(of: ")"),
                  open < close
            else { return nil }
            let uri = String(line[..<open]).trimmingCharacters(in: .whitespaces)
            guard uri.hasPrefix("/usb/") || uri.hasPrefix("hp:") else { return nil }
            let inside = String(line[line.index(after: open)..<close])
            let label = inside
                .replacingOccurrences(of: "Hewlett-Packard ", with: "HP ")
                .replacingOccurrences(of: "_", with: " ")
            return ScannerDevice(uri: uri, label: label)
        }
    }

    static func run(
        executable: String,
        arguments: [String],
        job: ScanJob
    ) -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err

        do {
            try process.run()
        } catch {
            return CommandResult(status: 1, stdout: "", stderr: error.localizedDescription)
        }
        job.attach(process)

        let outHandle = out.fileHandleForReading
        let errHandle = err.fileHandleForReading
        let group = DispatchGroup()
        var outData = Data()
        var errData = Data()
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            outData = outHandle.readDataToEndOfFile()
            group.leave()
        }
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            errData = errHandle.readDataToEndOfFile()
            group.leave()
        }
        process.waitUntilExit()
        group.wait()
        job.detach(process)

        let stdout = String(data: outData, encoding: .utf8) ?? ""
        let stderr = String(data: errData, encoding: .utf8) ?? ""
        return CommandResult(status: process.terminationStatus, stdout: stdout, stderr: stderr)
    }
}

final class ScanJob: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var cancelled = false

    func attach(_ process: Process) {
        lock.lock()
        self.process = process
        let shouldStop = cancelled
        lock.unlock()
        if shouldStop {
            process.terminate()
        }
    }

    func detach(_ process: Process) {
        lock.lock()
        if self.process === process {
            self.process = nil
        }
        lock.unlock()
    }

    func cancel() {
        lock.lock()
        cancelled = true
        process?.terminate()
        lock.unlock()
    }

    var wasCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }
}
