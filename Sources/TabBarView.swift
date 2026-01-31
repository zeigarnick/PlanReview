import SwiftUI
import AppKit

/// Visual tab bar at top of window showing all open review documents
struct TabBarView: View {
    @EnvironmentObject var tabManager: TabManager
    @State private var showCloseConfirmation = false
    @State private var documentToClose: ReviewDocument?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 1) {
                ForEach(Array(tabManager.documents.enumerated()), id: \.element.id) { index, doc in
                    TabItemView(
                        document: doc,
                        index: index,
                        isSelected: doc.id == tabManager.selectedDocumentID,
                        onSelect: { tabManager.selectedDocumentID = doc.id },
                        onClose: { requestCloseTab(doc) }
                    )
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 36)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.8))
        .alert("Close without submitting?", isPresented: $showCloseConfirmation) {
            Button("Cancel", role: .cancel) {
                documentToClose = nil
            }
            Button("Close", role: .destructive) {
                if let doc = documentToClose {
                    tabManager.closeDocument(doc)
                }
                documentToClose = nil
            }
        } message: {
            Text("This review has comments that haven't been submitted.")
        }
    }
    
    private func requestCloseTab(_ document: ReviewDocument) {
        if !document.comments.isEmpty {
            documentToClose = document
            showCloseConfirmation = true
        } else {
            tabManager.closeDocument(document)
        }
    }
}

/// Individual tab item in the tab bar
struct TabItemView: View {
    let document: ReviewDocument
    let index: Int
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    
    @State private var isHovering = false
    @State private var isCloseHovering = false
    
    var body: some View {
        HStack(spacing: 6) {
            // Tab number badge (for keyboard shortcut hint) - shows ⌘1, ⌘2, etc.
            if index < 9 {
                Text("⌘\(index + 1)")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
            
            // Filename
            Text(document.filename)
                .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                .lineLimit(1)
                .foregroundStyle(isSelected ? .primary : .secondary)
            
            // Comment count badge
            if !document.comments.isEmpty {
                Text("\(document.comments.count)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.orange)
                    .clipShape(Capsule())
            }
            
            // Close button
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(isCloseHovering ? .primary : .tertiary)
                    .frame(width: 16, height: 16)
                    .background(isCloseHovering ? Color.primary.opacity(0.1) : Color.clear)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .opacity(isHovering || isSelected ? 1 : 0)
            .onHover { hovering in
                isCloseHovering = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color(nsColor: .controlBackgroundColor) : (isHovering ? Color.primary.opacity(0.05) : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? Color.primary.opacity(0.1) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { isHovering = $0 }
    }
}
