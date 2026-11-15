import SwiftUI

@main
struct DeskJetScanApp: App {
    @State private var model = ScanModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
        }
        .defaultSize(width: 980, height: 680)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Scan") {
                Button("Scan") {
                    Task { await model.scan() }
                }
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(model.isBusy || model.selectedDevice == nil || model.isCropping)

                Button("Refresh Scanners") {
                    Task { await model.refresh() }
                }
                .disabled(model.isBusy)
            }
            CommandMenu("Edit") {
                Button("Rotate Left") { model.rotateLeft() }
                    .keyboardShortcut("[", modifiers: [.command])
                    .disabled(!model.canEdit)
                Button("Rotate Right") { model.rotateRight() }
                    .keyboardShortcut("]", modifiers: [.command])
                    .disabled(!model.canEdit)
                Divider()
                Button("Crop…") { model.beginCrop() }
                    .keyboardShortcut("k", modifiers: [.command])
                    .disabled(!model.canEdit)
                Button("Apply Crop") { model.applyCrop() }
                    .disabled(!model.isCropping)
                Button("Cancel Crop") { model.cancelCrop() }
                    .disabled(!model.isCropping)
            }
        }
    }
}
