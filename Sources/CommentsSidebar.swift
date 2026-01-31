import SwiftUI

struct CommentsSidebar: View {
    @EnvironmentObject var document: ReviewDocument
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Comments")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                if !document.comments.isEmpty {
                    Text("\(document.comments.count)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
            
            if document.comments.isEmpty {
                EmptyCommentsView()
            } else {
                CommentsListView()
            }
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }
}

struct EmptyCommentsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "text.bubble")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            
            VStack(spacing: 4) {
                Text("No comments")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                
                Text("Select text + ⌘K")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxHeight: .infinity)
    }
}

struct CommentsListView: View {
    @EnvironmentObject var document: ReviewDocument
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(document.comments) { comment in
                    CommentRow(comment: comment)
                    if comment.id != document.comments.last?.id {
                        Divider().padding(.leading, 16)
                    }
                }
            }
        }
    }
}

struct CommentRow: View {
    let comment: Comment
    @EnvironmentObject var document: ReviewDocument
    @State private var isHovered = false
    @State private var isDeleteHovered = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Content
            VStack(alignment: .leading, spacing: 4) {
                // Selected text (if any)
                if !comment.selectedText.isEmpty {
                    Text(comment.selectedText)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                
                // Comment text
                Text(comment.text)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                // Scroll to highlight in document
                NotificationCenter.default.post(
                    name: .scrollToComment,
                    object: nil,
                    userInfo: ["commentId": comment.id.uuidString]
                )
            }
            
            // Delete button - with hover background
            Button {
                document.removeComment(comment)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundStyle(isDeleteHovered ? Color.red : Color.gray)
                    .frame(width: 28, height: 28)
                    .background(isDeleteHovered ? Color.red.opacity(0.1) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isDeleteHovered = hovering
                if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(isHovered ? Color.primary.opacity(0.03) : Color.clear)
        .onHover { isHovered = $0 }
    }
}

extension Notification.Name {
    static let scrollToComment = Notification.Name("scrollToComment")
}
