import SwiftUI

struct ContentView: View {
    @Bindable var model: ScanModel

    var body: some View {
        HStack(spacing: 0) {
            controls
                .frame(width: 320)
            Divider()
            preview
        }
        .frame(minWidth: 920, minHeight: 600)
        .task { await model.refresh() }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("DeskJet Scan")
                    .font(.title2.weight(.semibold))
                Text("Scans the USB DeskJet 2300 series through hp-scan.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Scanner")
                    .font(.headline)
                if model.devices.isEmpty {
                    Text(model.toolPath == nil ? "hp-scan not installed" : "None found")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Scanner", selection: $model.selectedURI) {
                        ForEach(model.devices) { device in
                            Text(device.label).tag(device.uri)
                        }
                    }
                    .labelsHidden()
                    .disabled(model.isBusy)
                }
                Button("Refresh") {
                    Task { await model.refresh() }
                }
                .disabled(model.isBusy)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Page")
                    .font(.headline)
                Picker("Mode", selection: $model.mode) {
                    ForEach(ScanMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(model.isBusy)

                Picker("Resolution", selection: $model.dpi) {
                    ForEach(model.resolutions, id: \.self) { value in
                        Text("\(value) dpi").tag(value)
                    }
                }
                .disabled(model.isBusy)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Edit")
                    .font(.headline)
                HStack(spacing: 8) {
                    Button("Rotate Left") { model.rotateLeft() }
                        .disabled(!model.canEdit)
                    Button("Rotate Right") { model.rotateRight() }
                        .disabled(!model.canEdit)
                }
                if model.isCropping {
                    HStack(spacing: 8) {
                        Button("Apply Crop") { model.applyCrop() }
                        Button("Cancel") { model.cancelCrop() }
                    }
                } else {
                    Button("Crop…") { model.beginCrop() }
                        .disabled(!model.canEdit)
                }
            }

            HStack {
                Button(model.phase == .scanning || model.phase == .finishing ? "Scanning…" : "Scan") {
                    Task { await model.scan() }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(model.isBusy || model.selectedDevice == nil || model.isCropping)

                if model.isBusy {
                    Button("Cancel") { model.cancel() }
                }
            }

            Button("Show in Finder") { model.revealLastScan() }
                .disabled(model.lastFile == nil)

            Spacer()

            Text(model.status)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
    }

    private var preview: some View {
        ZStack {
            Color(nsColor: .underPageBackgroundColor)

            if let image = model.preview {
                PreviewCanvas(image: image, model: model)
                    .padding(24)
                    .opacity(model.previewVisible ? 1 : 0)
                    .scaleEffect(model.previewVisible ? 1 : 0.96)
                    .offset(y: model.previewVisible ? 0 : 12)
            } else if model.phase == .idle {
                VStack(spacing: 10) {
                    Image(systemName: "doc.viewfinder")
                        .font(.system(size: 42))
                        .foregroundStyle(.secondary)
                    Text("Place the page face down on the glass.")
                        .foregroundStyle(.secondary)
                }
            }

            if model.phase == .scanning || model.phase == .finishing {
                ProgressReveal(progress: model.progress, finishing: model.phase == .finishing)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.phase)
    }
}

/// Fits the bitmap by **pixel** aspect, then puts the crop overlay on that same rect.
private struct PreviewCanvas: View {
    var image: NSImage
    @Bindable var model: ScanModel

    var body: some View {
        GeometryReader { proxy in
            let pixels = ImageEditing.pixelSize(of: image)
            let fitted = Self.fittedSize(imageSize: pixels, in: proxy.size)
            let origin = CGPoint(
                x: (proxy.size.width - fitted.width) / 2,
                y: (proxy.size.height - fitted.height) / 2
            )
            let imageFrame = CGRect(origin: origin, size: fitted)

            ZStack(alignment: .topLeading) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: fitted.width, height: fitted.height)
                    .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
                    .offset(x: origin.x, y: origin.y)

                if model.isCropping {
                    CropSurface(rect: $model.cropRect, imageFrame: imageFrame)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
    }

    static func fittedSize(imageSize: CGSize, in bounds: CGSize) -> CGSize {
        guard imageSize.width > 0, imageSize.height > 0, bounds.width > 0, bounds.height > 0 else {
            return bounds
        }
        let scale = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
        return CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }
}

private struct ProgressReveal: View {
    var progress: Double
    var finishing: Bool

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.18), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        Color.accentColor,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(finishing ? .easeOut(duration: 0.28) : .linear(duration: 0.08), value: progress)

                Text("\(Int((progress * 100).rounded()))%")
                    .font(.system(.title2, design: .rounded).monospacedDigit().weight(.medium))
                    .contentTransition(.numericText())
            }
            .frame(width: 108, height: 108)

            Text(finishing ? "Finishing…" : "Scanning…")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 16, y: 6)
    }
}

private enum CropHandle: CaseIterable, Identifiable {
    case topLeft, topRight, bottomLeft, bottomRight
    var id: Self { self }
}

private struct CropSurface: View {
    @Binding var rect: CGRect
    var imageFrame: CGRect
    @State private var dragStart: CGRect?
    @State private var handleStart: CGRect?

    var body: some View {
        ZStack(alignment: .topLeading) {
            Path { path in
                path.addRect(imageFrame)
                path.addRect(cropFrame)
            }
            .fill(Color.black.opacity(0.45), style: FillStyle(eoFill: true))
            .allowsHitTesting(false)

            Rectangle()
                .strokeBorder(Color.white, lineWidth: 1.5)
                .background(Color.white.opacity(0.001))
                .frame(width: cropFrame.width, height: cropFrame.height)
                .offset(x: cropFrame.minX, y: cropFrame.minY)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let start = dragStart ?? rect
                            if dragStart == nil { dragStart = rect }
                            let dx = value.translation.width / max(imageFrame.width, 1)
                            let dy = value.translation.height / max(imageFrame.height, 1)
                            var next = start
                            next.origin.x = min(max(0, start.origin.x + dx), 1 - start.width)
                            next.origin.y = min(max(0, start.origin.y + dy), 1 - start.height)
                            rect = next
                        }
                        .onEnded { _ in dragStart = nil }
                )

            ForEach(CropHandle.allCases) { handle in
                Circle()
                    .fill(Color.white)
                    .frame(width: 12, height: 12)
                    .shadow(radius: 1)
                    .position(point(for: handle))
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let start = handleStart ?? rect
                                if handleStart == nil { handleStart = rect }
                                rect = resized(start: start, handle: handle, translation: value.translation)
                            }
                            .onEnded { _ in handleStart = nil }
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var cropFrame: CGRect {
        CGRect(
            x: imageFrame.minX + rect.minX * imageFrame.width,
            y: imageFrame.minY + rect.minY * imageFrame.height,
            width: rect.width * imageFrame.width,
            height: rect.height * imageFrame.height
        )
    }

    private func point(for handle: CropHandle) -> CGPoint {
        let f = cropFrame
        switch handle {
        case .topLeft: return CGPoint(x: f.minX, y: f.minY)
        case .topRight: return CGPoint(x: f.maxX, y: f.minY)
        case .bottomLeft: return CGPoint(x: f.minX, y: f.maxY)
        case .bottomRight: return CGPoint(x: f.maxX, y: f.maxY)
        }
    }

    private func resized(start: CGRect, handle: CropHandle, translation: CGSize) -> CGRect {
        let dx = translation.width / max(imageFrame.width, 1)
        let dy = translation.height / max(imageFrame.height, 1)
        var left = start.minX
        var top = start.minY
        var right = start.maxX
        var bottom = start.maxY
        let minSize: CGFloat = 0.05

        switch handle {
        case .topLeft:
            left = min(right - minSize, max(0, start.minX + dx))
            top = min(bottom - minSize, max(0, start.minY + dy))
        case .topRight:
            right = max(left + minSize, min(1, start.maxX + dx))
            top = min(bottom - minSize, max(0, start.minY + dy))
        case .bottomLeft:
            left = min(right - minSize, max(0, start.minX + dx))
            bottom = max(top + minSize, min(1, start.maxY + dy))
        case .bottomRight:
            right = max(left + minSize, min(1, start.maxX + dx))
            bottom = max(top + minSize, min(1, start.maxY + dy))
        }
        return CGRect(x: left, y: top, width: right - left, height: bottom - top)
    }
}
