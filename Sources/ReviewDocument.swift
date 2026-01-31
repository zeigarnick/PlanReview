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

/// Per-tab review model - each tab has its own independent ReviewDocument
@MainActor
class ReviewDocument: ObservableObject, Identifiable {
    let id = UUID()
    let filePath: String
    
    @Published var markdownContent: String = ""
    @Published var comments: [Comment] = []
    @Published var selectedText: String = ""
    @Published var selectedLineNumber: Int = 0
    @Published var isAddingComment: Bool = false
    @Published var hasUnsavedChanges: Bool = false
    
    var filename: String {
        URL(fileURLWithPath: filePath).lastPathComponent
    }
    
    init(filePath: String) {
        self.filePath = filePath
        loadFile()
    }
    
    private func loadFile() {
        do {
            self.markdownContent = try String(contentsOfFile: filePath, encoding: .utf8)
            loadComments()
            self.hasUnsavedChanges = false
        } catch {
            print("Error loading file: \(error)")
        }
    }
    
    private func loadComments() {
        let commentsPath = filePath.replacingOccurrences(of: ".md", with: ".comments.json")
        
        if FileManager.default.fileExists(atPath: commentsPath) {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: commentsPath))
                comments = try JSONDecoder().decode([Comment].self, from: data)
            } catch {
                print("Error loading comments: \(error)")
            }
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
    
    func approve() {
        saveAndSignal(approved: true)
    }
    
    func requestChanges() {
        saveAndSignal(approved: false)
    }
    
    /// Saves the review and writes the .done signal file
    /// Does NOT terminate the app - TabManager handles lifecycle
    private func saveAndSignal(approved: Bool) {
        do {
            // Save updated markdown
            try markdownContent.write(toFile: filePath, atomically: true, encoding: .utf8)
            
            // Save comments
            let commentsPath = filePath.replacingOccurrences(of: ".md", with: ".comments.json")
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let commentsData = try encoder.encode(comments)
            try commentsData.write(to: URL(fileURLWithPath: commentsPath))
            
            // Write completion signal
            let donePath = filePath.replacingOccurrences(of: ".md", with: ".done")
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
        } catch {
            print("Error saving: \(error)")
        }
    }
}
