import SwiftUI
import AppKit

struct MarkdownTextView: NSViewRepresentable {
    let attributedString: NSAttributedString
    let onSelectionChange: ((NSRange, String) -> Void)?
    let onLinkClick: ((URL) -> Void)?
    let onContentChange: ((String) -> Void)?
    let isEditable: Bool
    
    init(
        attributedString: NSAttributedString,
        isEditable: Bool = true,
        onSelectionChange: ((NSRange, String) -> Void)? = nil,
        onLinkClick: ((URL) -> Void)? = nil,
        onContentChange: ((String) -> Void)? = nil
    ) {
        self.attributedString = attributedString
        self.isEditable = isEditable
        self.onSelectionChange = onSelectionChange
        self.onLinkClick = onLinkClick
        self.onContentChange = onContentChange
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let theme = MarkdownTheme()
        
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = NSColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1.0)
        
        // Create text container with proper sizing
        let textContainer = NSTextContainer()
        textContainer.widthTracksTextView = true
        textContainer.heightTracksTextView = false
        
        // Create NSTextView with TextKit 2 for better performance
        let textView = NSTextView(usingTextLayoutManager: true)
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.drawsBackground = true
        textView.backgroundColor = NSColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1.0)
        
        // Generous padding like the CSS version
        textView.textContainerInset = NSSize(width: theme.contentInset, height: theme.contentInset)
        
        // Typography settings
        textView.isAutomaticLinkDetectionEnabled = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        
        // Rich text for proper formatting
        textView.isRichText = true
        textView.allowsUndo = true
        
        // Set insertion point color to be visible
        textView.insertionPointColor = .white
        
        textView.delegate = context.coordinator
        
        // Make text view resize with scroll view
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        
        scrollView.documentView = textView
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        
        // Only update if content changed and we're not currently editing
        let currentText = textView.attributedString().string
        let newText = attributedString.string
        
        if currentText != newText {
            // Preserve selection
            let selection = textView.selectedRange()
            textView.textStorage?.setAttributedString(attributedString)
            
            // Restore selection if valid
            if selection.location + selection.length <= textView.string.count {
                textView.setSelectedRange(selection)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        let parent: MarkdownTextView
        
        init(_ parent: MarkdownTextView) {
            self.parent = parent
        }
        
        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            let range = textView.selectedRange()
            
            if range.length > 0 {
                let text = (textView.string as NSString).substring(with: range)
                parent.onSelectionChange?(range, text)
            }
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.onContentChange?(textView.string)
        }
        
        func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
            if let url = link as? URL {
                parent.onLinkClick?(url)
                return true
            }
            return false
        }
    }
}
