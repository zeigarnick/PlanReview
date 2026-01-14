import SwiftUI
import AppKit

// MARK: - Cursor Helper (AppKit-level for overlay compatibility)

/// Uses NSTrackingArea with cursorUpdate to set cursor - works even with hitTest -> nil
/// This takes precedence over underlying view's cursor management
struct PointingHandCursorView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = ClickThroughCursorView()
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
    
    class ClickThroughCursorView: NSView {
        override init(frame: NSRect) {
            super.init(frame: frame)
            setupTrackingArea()
        }
        
        required init?(coder: NSCoder) {
            super.init(coder: coder)
            setupTrackingArea()
        }
        
        private func setupTrackingArea() {
            let options: NSTrackingArea.Options = [.cursorUpdate, .activeAlways, .inVisibleRect]
            let trackingArea = NSTrackingArea(rect: .zero, options: options, owner: self, userInfo: nil)
            addTrackingArea(trackingArea)
        }
        
        override func cursorUpdate(with event: NSEvent) {
            NSCursor.pointingHand.set()
        }
        
        // Pass clicks through to SwiftUI button underneath
        override func hitTest(_ point: NSPoint) -> NSView? {
            return nil
        }
    }
}

private struct HandCursorModifier: ViewModifier {
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .overlay(PointingHandCursorView())
            .onHover { hovering in
                if hovering {
                    if !isHovering {
                        NSCursor.pointingHand.push()
                    }
                } else if isHovering {
                    NSCursor.pop()
                }
                isHovering = hovering
            }
            .onDisappear {
                if isHovering {
                    NSCursor.pop()
                    isHovering = false
                }
            }
    }
}

extension View {
    /// Adds a pointing hand cursor that works even over NSViewRepresentable views
    func handCursor() -> some View {
        modifier(HandCursorModifier())
    }
}

struct ContentView: View {
    @EnvironmentObject var reviewState: ReviewState
    @State private var showComments = false
    
    var body: some View {
        HStack(spacing: 0) {
            MarkdownWebView()
                .frame(maxWidth: .infinity)
            
            if showComments {
                Divider()
                CommentsSidebar()
                    .frame(width: 320)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                if let path = reviewState.filePath {
                    Text(URL(fileURLWithPath: path).lastPathComponent)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                }
            }
            
            ToolbarItemGroup(placement: .primaryAction) {
                // Comments toggle with shortcut hint
                Button {
                    showComments.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showComments ? "bubble.left.and.bubble.right.fill" : "bubble.left.and.bubble.right")
                        if !reviewState.comments.isEmpty {
                            Text("\(reviewState.comments.count)")
                                .font(.caption2)
                                .fontWeight(.bold)
                        }
                        Text("⌘/")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                }
                .keyboardShortcut("/", modifiers: .command)
                .help("Toggle comments sidebar ⌘/")
                
                if !reviewState.comments.isEmpty {
                    Button("Request Changes") {
                        reviewState.requestChanges()
                    }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                }
                
                Button {
                    reviewState.approve()
                } label: {
                    HStack(spacing: 4) {
                        Text("Submit")
                        Text("⌘↵")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .keyboardShortcut(.return, modifiers: .command)
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            }
        }
        .onAppear {
            reviewState.loadFromCommandLine()
        }
    }
}

// MARK: - Markdown WebView

struct MarkdownWebView: View {
    @EnvironmentObject var reviewState: ReviewState
    @State private var selectedText: String = ""
    @State private var showCommentPopover: Bool = false
    @State private var commentText: String = ""
    @State private var editingComment: Comment? = nil
    @State private var pendingSelection: String = ""  // Stable snapshot for comment creation
    
    var body: some View {
        // Build the attributed string with markdown rendering and comment highlights
        let renderer = MarkdownRenderer()
        let baseAttributed = renderer.render(reviewState.markdownContent)
        let highlighter = CommentHighlighter()
        let highlighted = highlighter.applyHighlights(to: baseAttributed, comments: reviewState.comments)
        
        ZStack(alignment: .topLeading) {
            MarkdownTextView(
                attributedString: highlighted,
                isEditable: false,  // Read-only: editing rendered markdown destroys formatting
                onSelectionChange: { range, text in
                    selectedText = text
                },
                onLinkClick: { url in
                    NSWorkspace.shared.open(url)
                }
            )
            
            // Floating toolbar near selection - instant, no animation
            // Note: Using fixed position since NSTextView doesn't provide selection rect easily
            if !selectedText.isEmpty && editingComment == nil && !showCommentPopover {
                SelectionToolbar(
                    selectedText: selectedText,
                    onComment: {
                        pendingSelection = selectedText  // Snapshot before focus changes
                        showCommentPopover = true
                    }
                )
                .position(x: 200, y: 80)  // Fixed position at top-left area
            }
            
            // New comment popover
            if showCommentPopover {
                CommentPopover(
                    selectedText: pendingSelection,  // Use stable snapshot
                    commentText: $commentText,
                    position: CGPoint(x: 250, y: 120),  // Fixed position
                    isEditing: false,
                    onSubmit: {
                        if !commentText.isEmpty && !pendingSelection.isEmpty {
                            reviewState.selectedText = pendingSelection  // Use snapshot
                            reviewState.addComment(commentText)
                            commentText = ""
                            showCommentPopover = false
                            pendingSelection = ""
                            selectedText = ""
                        }
                    },
                    onDelete: nil,
                    onCancel: {
                        commentText = ""
                        showCommentPopover = false
                        pendingSelection = ""
                        selectedText = ""  // Clear selection to hide toolbar
                    }
                )
            }
            
            // Edit comment popover (reuses same component)
            // Note: editingComment is set via onEditComment which is no longer available
            // from MarkdownTextView. This will need to be handled via a different mechanism
            // (e.g., comments sidebar) in a future task.
            if let comment = editingComment {
                CommentPopover(
                    selectedText: comment.selectedText,
                    commentText: $commentText,
                    position: CGPoint(x: 250, y: 120),  // Fixed position
                    isEditing: true,
                    onSubmit: {
                        if !commentText.isEmpty {
                            reviewState.updateComment(comment, newText: commentText)
                        }
                        commentText = ""
                        editingComment = nil
                    },
                    onDelete: {
                        reviewState.removeComment(comment)
                        commentText = ""
                        editingComment = nil
                    },
                    onCancel: {
                        commentText = ""
                        editingComment = nil
                    }
                )
            }
            
        }
        .onReceive(NotificationCenter.default.publisher(for: .triggerAddComment)) { _ in
            if !selectedText.isEmpty {
                pendingSelection = selectedText  // Snapshot before focus changes
                showCommentPopover = true
            }
        }
    }
}

// MARK: - Selection Toolbar (instant, no animation)

struct SelectionToolbar: View {
    let selectedText: String
    let onComment: () -> Void
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 2) {
            Button(action: onComment) {
                HStack(spacing: 4) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 11))
                    Text("Comment")
                        .font(.system(size: 11, weight: .medium))
                    Text("⌘K")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isHovering ? Color.blue.opacity(0.8) : Color.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { isHovering = $0 }
            .handCursor()
        }
        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
    }
}

// MARK: - Comment Popover (inline, near selection)

struct CommentPopover: View {
    let selectedText: String
    @Binding var commentText: String
    let position: CGPoint
    let isEditing: Bool
    let onSubmit: () -> Void
    let onDelete: (() -> Void)?
    let onCancel: () -> Void
    
    @FocusState private var isFocused: Bool
    @State private var hoveringDelete = false
    @State private var hoveringCancel = false
    @State private var hoveringSubmit = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Selected text preview
            Text("\"\(selectedText.prefix(60))\(selectedText.count > 60 ? "..." : "")\"")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(2)
            
            // Input field - single line so Return submits
            TextField(isEditing ? "Edit comment..." : "Add comment...", text: $commentText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($isFocused)
                .onSubmit {
                    if !commentText.isEmpty {
                        onSubmit()
                    }
                }
            
            // Actions
            HStack {
                if isEditing, let onDelete = onDelete {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundStyle(.red)
                            .padding(6)
                            .background(hoveringDelete ? Color.red.opacity(0.1) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .onHover { hoveringDelete = $0 }
                    .handCursor()
                }
                
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(hoveringCancel ? Color.secondary.opacity(0.1) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
                .onHover { hoveringCancel = $0 }
                .handCursor()
                
                Spacer()
                
                Button(action: onSubmit) {
                    HStack(spacing: 3) {
                        Text(isEditing ? "Save" : "Add")
                        Text("↵")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(commentText.isEmpty ? Color.gray : (hoveringSubmit ? Color.blue.opacity(0.8) : Color.blue))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(commentText.isEmpty)
                .onHover { hoveringSubmit = $0 }
                .handCursor()
            }
        }
        .padding(12)
        .frame(width: 280)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 16, y: 8)
        .position(position)
        .onAppear {
            isFocused = true
        }
    }
}
