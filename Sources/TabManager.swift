import SwiftUI
import Combine

/// Centralized management of open review tabs
@MainActor
class TabManager: ObservableObject {
    @Published var documents: [ReviewDocument] = []
    @Published var selectedDocumentID: UUID?
    
    private var cancellables = Set<AnyCancellable>()
    
    var selectedDocument: ReviewDocument? {
        documents.first { $0.id == selectedDocumentID }
    }
    
    init() {
        setupNotifications()
    }
    
    private func setupNotifications() {
        // Listen for file open requests (from AppDelegate, command line, etc.)
        NotificationCenter.default.publisher(for: .openPlanFile)
            .compactMap { $0.userInfo?["path"] as? String }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] path in
                self?.openDocument(at: path)
            }
            .store(in: &cancellables)
    }
    
    func openDocument(at path: String) {
        // Prevent duplicate tabs for same file
        if let existing = documents.first(where: { $0.filePath == path }) {
            selectedDocumentID = existing.id
            return
        }
        
        let doc = ReviewDocument(filePath: path)
        documents.append(doc)
        selectedDocumentID = doc.id
    }
    
    func closeDocument(_ document: ReviewDocument) {
        documents.removeAll { $0.id == document.id }
        
        // Select next tab, or quit if none left
        if documents.isEmpty {
            NSApplication.shared.terminate(nil)
        } else if selectedDocumentID == document.id {
            // Select the last tab if we closed the selected one
            selectedDocumentID = documents.last?.id
        }
    }
    
    func submitAndClose(_ document: ReviewDocument) {
        document.approve()
        closeDocument(document)
    }
    
    func requestChangesAndClose(_ document: ReviewDocument) {
        document.requestChanges()
        closeDocument(document)
    }
    
    // MARK: - Tab Navigation
    
    func selectTab(at index: Int) {
        guard index >= 0, index < documents.count else { return }
        selectedDocumentID = documents[index].id
    }
    
    func selectNextTab() {
        guard let currentID = selectedDocumentID,
              let currentIndex = documents.firstIndex(where: { $0.id == currentID }) else { return }
        
        let nextIndex = (currentIndex + 1) % documents.count
        selectedDocumentID = documents[nextIndex].id
    }
    
    func selectPreviousTab() {
        guard let currentID = selectedDocumentID,
              let currentIndex = documents.firstIndex(where: { $0.id == currentID }) else { return }
        
        let prevIndex = currentIndex > 0 ? currentIndex - 1 : documents.count - 1
        selectedDocumentID = documents[prevIndex].id
    }
    
    /// Load file from command line arguments (called on app launch)
    func loadFromCommandLine() {
        let args = CommandLine.arguments
        if args.count > 1 {
            openDocument(at: args[1])
        }
    }
}
