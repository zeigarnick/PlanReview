import SwiftUI

/// Main window container with tab bar and content area
struct MainWindowView: View {
    @EnvironmentObject var tabManager: TabManager
    @State private var showComments = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab bar (only show if multiple tabs)
            if tabManager.documents.count > 1 {
                TabBarView()
                Divider()
            }
            
            // Content area
            if let document = tabManager.selectedDocument {
                ReviewTabView(document: document, showComments: $showComments)
            } else {
                EmptyStateView()
            }
        }
        .onAppear {
            tabManager.loadFromCommandLine()
        }
    }
}

/// Content view for a single review tab
struct ReviewTabView: View {
    @ObservedObject var document: ReviewDocument
    @EnvironmentObject var tabManager: TabManager
    @Binding var showComments: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            ContentView()
                .environmentObject(document)
                .frame(maxWidth: .infinity)
            
            if showComments {
                Divider()
                CommentsSidebar()
                    .environmentObject(document)
                    .frame(width: 320)
            }
        }

        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Text(document.filename)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
            }
            
            ToolbarItemGroup(placement: .primaryAction) {
                // Comments toggle
                Button {
                    showComments.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showComments ? "bubble.left.and.bubble.right.fill" : "bubble.left.and.bubble.right")
                        if !document.comments.isEmpty {
                            Text("\(document.comments.count)")
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
                
                // Request Changes button (only if has comments)
                if !document.comments.isEmpty {
                    Button("Request Changes") {
                        tabManager.requestChangesAndClose(document)
                    }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                }
                
                // Submit button
                Button {
                    tabManager.submitAndClose(document)
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
    }
}

/// Empty state when no documents are open
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("No plans to review")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Open a plan file or wait for submit_plan calls")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
