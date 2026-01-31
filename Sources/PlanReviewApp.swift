import SwiftUI
import UniformTypeIdentifiers

@main
struct PlanReviewApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var tabManager = TabManager()
    
    var body: some Scene {
        WindowGroup {
            MainWindowView()
                .environmentObject(tabManager)
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
            
            // Tab navigation commands
            CommandGroup(after: .toolbar) {
                Divider()
                
                Button("Next Tab") {
                    tabManager.selectNextTab()
                }
                .keyboardShortcut("]", modifiers: .command)
                .disabled(tabManager.documents.count < 2)
                
                Button("Previous Tab") {
                    tabManager.selectPreviousTab()
                }
                .keyboardShortcut("[", modifiers: .command)
                .disabled(tabManager.documents.count < 2)
                
                Divider()
                
                // Direct tab access like Ghostty/Safari: ⌘1 through ⌘9
                ForEach(0..<min(9, tabManager.documents.count), id: \.self) { index in
                    Button("Tab \(index + 1): \(tabManager.documents[index].filename)") {
                        tabManager.selectTab(at: index)
                    }
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
                }
            }
        }
        .onChange(of: tabManager.documents.count) { oldValue, newValue in
            // Wire up AppDelegate reference when TabManager is initialized
            appDelegate.tabManager = tabManager
        }
    }
    
    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.plainText, UTType(filenameExtension: "md")!]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Select a Markdown file to review"
        
        if panel.runModal() == .OK, let url = panel.url {
            tabManager.openDocument(at: url.path)
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil),
                  url.pathExtension == "md" else { return }
            
            DispatchQueue.main.async {
                tabManager.openDocument(at: url.path)
            }
        }
        return true
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    weak var tabManager: TabManager?
    
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if url.scheme == "planreview" || url.isFileURL {
                // Post notification that TabManager listens to
                NotificationCenter.default.post(
                    name: .openPlanFile,
                    object: nil,
                    userInfo: ["path": url.path]
                )
            }
        }
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.servicesProvider = self
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

extension Notification.Name {
    static let openPlanFile = Notification.Name("openPlanFile")
    static let triggerAddComment = Notification.Name("triggerAddComment")
}
