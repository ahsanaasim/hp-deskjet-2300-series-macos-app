import AppKit
import Foundation
import Observation
import SwiftUI

enum ScanMode: String, CaseIterable, Identifiable {
    case color = "Color"
    case gray = "Gray"

    var id: String { rawValue }
    var title: String { self == .color ? "Color" : "Grayscale" }
}

enum ScanPhase: Equatable {
    case idle
    case scanning
    case finishing
    case revealing
}

@MainActor
@Observable
final class ScanModel {
    var devices: [ScannerDevice] = []
    var selectedURI = ""
    var mode: ScanMode = .color
    var dpi = 300
    var status = "Looking for the DeskJet…"
    var isBusy = false
    var phase: ScanPhase = .idle
    var progress: Double = 0
    var preview: NSImage?
    var previewVisible = false
    var lastFile: URL?
    var toolPath: String?
    var isCropping = false
    /// Normalized crop rect in image space (origin top-left).
    var cropRect = CGRect(x: 0.08, y: 0.08, width: 0.84, height: 0.84)

    private var job: ScanJob?
    private var progressTask: Task<Void, Never>?

    let resolutions = [75, 150, 300, 600]

    var selectedDevice: ScannerDevice? {
        devices.first { $0.uri == selectedURI } ?? devices.first
    }

    var canEdit: Bool {
        preview != nil && phase == .idle && !isBusy
    }

    func refresh() async {
        guard !isBusy else { return }
        guard let tool = HPScanCLI.locate() else {
            toolPath = nil
            devices = []
            status = "hp-scan is not installed. From this project run: sh install.sh --scan-only"
            return
        }
        toolPath = tool
        isBusy = true
        status = "Looking for scanners…"
        let job = ScanJob()
        self.job = job
        let result = await Task.detached {
            HPScanCLI.run(executable: tool, arguments: ["-L"], job: job)
        }.value
        self.job = nil
        isBusy = false

        let found = HPScanCLI.parseDevices(result.stdout)
        devices = found
        if selectedURI.isEmpty || !found.contains(where: { $0.uri == selectedURI }) {
            selectedURI = found.first?.uri ?? ""
        }
        if let device = selectedDevice {
            status = "Ready — \(device.label)"
        } else if job.wasCancelled {
            status = "Search cancelled."
        } else {
            status = "No scanner found. Turn the DeskJet on and check the USB cable."
        }
    }

    func scan() async {
        guard !isBusy else { return }
        guard let tool = toolPath ?? HPScanCLI.locate() else {
            status = "hp-scan is not installed."
            return
        }
        guard let device = selectedDevice else {
            status = "No scanner selected."
            return
        }

        let folder = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop/Scans", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            status = "Could not create \(folder.path): \(error.localizedDescription)"
            return
        }

        let stamp = Self.stamp.string(from: Date())
        let output = folder.appendingPathComponent("scan_\(stamp)_\(dpi)dpi.png")
        let arguments = [
            "-m", mode.rawValue,
            "-r", String(dpi),
            "-d", device.uri,
            "-o", output.path,
        ]

        isBusy = true
        isCropping = false
        previewVisible = false
        preview = nil
        beginSlowProgress()
        status = "Scanning at \(dpi) dpi. Keep the lid closed."

        let job = ScanJob()
        self.job = job
        let result = await Task.detached {
            HPScanCLI.run(executable: tool, arguments: arguments, job: job)
        }.value
        self.job = nil

        let fileOK = (try? output.resourceValues(forKeys: [.fileSizeKey]).fileSize).map { $0 > 32 } ?? false
        if job.wasCancelled {
            stopProgress()
            try? FileManager.default.removeItem(at: output)
            phase = .idle
            progress = 0
            isBusy = false
            status = "Scan cancelled."
            return
        }

        if fileOK && result.status == 0 {
            lastFile = output
            let image = NSImage(contentsOf: output).map(ImageEditing.normalized)
            await completeProgress(with: image)
            status = Self.describe(stderr: result.stderr, fallback: "Saved \(output.lastPathComponent)")
            isBusy = false
            return
        }

        stopProgress()
        phase = .idle
        progress = 0
        isBusy = false
        let detail = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        status = detail.isEmpty ? "Scan failed (exit \(result.status))." : Self.describe(stderr: detail, fallback: detail)
    }

    func cancel() {
        job?.cancel()
        status = "Cancelling…"
    }

    func revealLastScan() {
        guard let lastFile else { return }
        NSWorkspace.shared.activateFileViewerSelecting([lastFile])
    }

    func rotateLeft() {
        applyEdit { ImageEditing.rotate($0, degrees: 90) }
    }

    func rotateRight() {
        applyEdit { ImageEditing.rotate($0, degrees: -90) }
    }

    func beginCrop() {
        guard canEdit else { return }
        cropRect = CGRect(x: 0.08, y: 0.08, width: 0.84, height: 0.84)
        isCropping = true
        status = "Drag the crop box, then Apply Crop."
    }

    func cancelCrop() {
        isCropping = false
        if let device = selectedDevice {
            status = "Ready — \(device.label)"
        }
    }

    func applyCrop() {
        guard canEdit || isCropping, let image = preview else { return }
        guard let cropped = ImageEditing.crop(image, normalized: cropRect) else {
            status = "Crop failed."
            return
        }
        preview = ImageEditing.normalized(cropped)
        isCropping = false
        persistPreview()
        status = "Cropped and saved."
    }

    private func applyEdit(_ transform: (NSImage) -> NSImage?) {
        guard canEdit, let image = preview, let next = transform(image) else { return }
        preview = ImageEditing.normalized(next)
        persistPreview()
        status = "Saved edit."
    }

    private func persistPreview() {
        guard let preview, let lastFile else { return }
        do {
            try ImageEditing.writePNG(preview, to: lastFile)
        } catch {
            status = error.localizedDescription
        }
    }

    private func beginSlowProgress() {
        progressTask?.cancel()
        phase = .scanning
        progress = 0.02
        // hp-scan never reports a percentage, so ease toward ~90% while waiting.
        progressTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 40_000_000)
                guard let self, !Task.isCancelled else { return }
                await MainActor.run {
                    guard self.phase == .scanning else { return }
                    let remaining = 0.90 - self.progress
                    self.progress += max(0.0015, remaining * 0.018)
                    if self.progress > 0.90 { self.progress = 0.90 }
                }
            }
        }
    }

    private func stopProgress() {
        progressTask?.cancel()
        progressTask = nil
    }

    private func completeProgress(with image: NSImage?) async {
        stopProgress()
        phase = .finishing
        withAnimation(.easeOut(duration: 0.28)) {
            progress = 1
        }
        try? await Task.sleep(nanoseconds: 320_000_000)

        guard let image else {
            phase = .idle
            progress = 0
            return
        }

        phase = .revealing
        preview = image
        withAnimation(.easeOut(duration: 0.55)) {
            previewVisible = true
        }
        try? await Task.sleep(nanoseconds: 560_000_000)
        withAnimation(.easeOut(duration: 0.25)) {
            phase = .idle
            progress = 0
        }
    }

    private static let stamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd_HH.mm.ss"
        return formatter
    }()

    private static func describe(stderr: String, fallback: String) -> String {
        let lines = stderr.split(separator: "\n").map { String($0) }
        if let size = lines.first(where: { $0.contains("hp-scan:") && $0.contains("dpi") }) {
            return size
                .replacingOccurrences(of: "hp-scan: ", with: "")
                .replacingOccurrences(of: "Gray", with: "grayscale")
                .replacingOccurrences(of: "Color", with: "color")
        }
        if stderr.contains("готово") {
            return fallback
        }
        let cleaned = lines
            .map { $0.replacingOccurrences(of: "hp-scan: ", with: "") }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        return cleaned.isEmpty ? fallback : cleaned
    }
}
