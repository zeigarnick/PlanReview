import SwiftUI
import Combine

struct Comment: Identifiable, Codable {
    let id: UUID
    var text: String
    var selectedRange: Range<String.Index>?
    var selectedText: String
    var lineNumber: Int
    var resolved: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case id, text, selectedText, lineNumber, resolved
    }
    
    init(id: UUID = UUID(), text: String, selectedText: String, lineNumber: Int) {
        self.id = id
        self.text = text
        self.selectedText = selectedText
        self.lineNumber = lineNumber
    }
}

@MainActor
class ReviewState: ObservableObject {
    @Published var filePath: String?
    @Published var markdownContent: String = ""
    @Published var comments: [Comment] = []
    @Published var selectedText: String = ""
    @Published var selectedLineNumber: Int = 0
    @Published var isAddingComment: Bool = false
    @Published var hasUnsavedChanges: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupNotifications()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.publisher(for: .openPlanFile)
            .compactMap { $0.userInfo?["path"] as? String }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] path in
                self?.loadFile(at: path)
            }
            .store(in: &cancellables)
    }
    
    func loadFile(at path: String) {
        self.filePath = path
        do {
            self.markdownContent = try String(contentsOfFile: path, encoding: .utf8)
            loadComments()
            self.hasUnsavedChanges = false
        } catch {
            print("Error loading file: \(error)")
        }
    }
    
    func loadFromCommandLine() {
        let args = CommandLine.arguments
        if args.count > 1 {
            loadFile(at: args[1])
        }
    }
    
    func addComment(_ text: String) {
        let comment = Comment(
            text: text,
            selectedText: selectedText,
            lineNumber: selectedLineNumber
        )
        comments.append(comment)
        hasUnsavedChanges = true
        isAddingComment = false
        selectedText = ""
    }
    
    func removeComment(_ comment: Comment) {
        comments.removeAll { $0.id == comment.id }
        hasUnsavedChanges = true
    }
    
    func updateComment(_ comment: Comment, newText: String) {
        if let index = comments.firstIndex(where: { $0.id == comment.id }) {
            comments[index].text = newText
            hasUnsavedChanges = true
        }
    }
    
    func updateContent(_ newContent: String) {
        markdownContent = newContent
        hasUnsavedChanges = true
    }
    
    private func loadComments() {
        guard let path = filePath else { return }
        let commentsPath = path.replacingOccurrences(of: ".md", with: ".comments.json")
        
        if FileManager.default.fileExists(atPath: commentsPath) {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: commentsPath))
                comments = try JSONDecoder().decode([Comment].self, from: data)
            } catch {
                print("Error loading comments: \(error)")
            }
        }
    }
    
    func approve() {
        saveAndSignal(approved: true)
    }
    
    func requestChanges() {
        saveAndSignal(approved: false)
    }
    
    private func saveAndSignal(approved: Bool) {
        guard let path = filePath else { return }
        
        do {
            // Save updated markdown
            try markdownContent.write(toFile: path, atomically: true, encoding: .utf8)
            
            // Save comments
            let commentsPath = path.replacingOccurrences(of: ".md", with: ".comments.json")
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let commentsData = try encoder.encode(comments)
            try commentsData.write(to: URL(fileURLWithPath: commentsPath))
            
            // Write completion signal
            let donePath = path.replacingOccurrences(of: ".md", with: ".done")
            let status = approved ? "approved" : "changes_requested"
            let signal = """
            {
                "status": "\(status)",
                "commentCount": \(comments.count),
                "timestamp": "\(ISO8601DateFormatter().string(from: Date()))"
            }
            """
            try signal.write(toFile: donePath, atomically: true, encoding: .utf8)
            
            hasUnsavedChanges = false
            
            // Quit the app after saving
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NSApplication.shared.terminate(nil)
            }
        } catch {
            print("Error saving: \(error)")
        }
    }
}
