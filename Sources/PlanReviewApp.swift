import SwiftUI
import UniformTypeIdentifiers

@main
struct PlanReviewApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var reviewState = ReviewState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(reviewState)
                .frame(minWidth: 900, minHeight: 700)
                .preferredColorScheme(.dark)
                .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                    handleDrop(providers: providers)
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            // File > Open
            CommandGroup(replacing: .newItem) {
                Button("Open...") {
                    openFilePicker()
                }
                .keyboardShortcut("o", modifiers: .command)
            }
            
            CommandGroup(after: .textEditing) {
                Button("Add Comment") {
                    NotificationCenter.default.post(name: .triggerAddComment, object: nil)
                }
                .keyboardShortcut("k", modifiers: .command)
            }
        }
    }
    
    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.plainText, UTType(filenameExtension: "md")!]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Select a Markdown file to review"
        
        if panel.runModal() == .OK, let url = panel.url {
            NotificationCenter.default.post(
                name: .openPlanFile,
                object: nil,
                userInfo: ["path": url.path]
            )
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil),
                  url.pathExtension == "md" else { return }
            
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .openPlanFile,
                    object: nil,
                    userInfo: ["path": url.path]
                )
            }
        }
        return true
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        
        // Handle both planreview:// URLs and file URLs
        if url.scheme == "planreview" {
            NotificationCenter.default.post(
                name: .openPlanFile,
                object: nil,
                userInfo: ["path": url.path]
            )
        } else if url.isFileURL {
            NotificationCenter.default.post(
                name: .openPlanFile,
                object: nil,
                userInfo: ["path": url.path]
            )
        }
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Register as handler for .md files
        NSApp.servicesProvider = self
    }
}

extension Notification.Name {
    static let openPlanFile = Notification.Name("openPlanFile")
    static let triggerAddComment = Notification.Name("triggerAddComment")
}
