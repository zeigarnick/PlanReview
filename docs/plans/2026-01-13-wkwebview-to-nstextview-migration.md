# WKWebView to NSTextView Migration Plan

> **For Agent:** Execute this plan task-by-task with proper testing and code review.

**Goal:** Replace `WKWebView`-based Markdown rendering with a native `NSTextView` pipeline, preserving comment highlighting, link handling, and selection.

**Architecture:** Parse Markdown via Apple's `swift-markdown` into an AST, walk with a `MarkupVisitor` to produce `NSAttributedString`, display in a TextKit 2 `NSTextView`. Comment highlights applied via text attributes.

**Tech Stack:** SwiftUI, AppKit (NSTextView), TextKit 2, swift-markdown, Highlightr (optional for code blocks)

**Target:** macOS 12+

**Beads Issue:** N/A

---

## Current State

The existing implementation lives in `Sources/ContentView.swift`:

- **Parsing:** Uses [Ink](https://github.com/JohnSundell/Ink) library (`MarkdownParser().html(from:)`)
- **Rendering:** `WKWebView` with inlined CSS/JS (~600 lines)
- **Comment Highlights:** JavaScript finds text ranges and wraps with `<span class="comment-highlight">`
- **Editing:** `contenteditable="true"` div with JS keyboard handlers
- **Communication:** `WKScriptMessageHandler` bridges JS ↔ Swift for selection/comments

### What We're Keeping
- Comment data model and sidebar (`CommentsSidebar.swift`)
- Plan loading/saving logic
- Overall SwiftUI structure

### What We're Replacing
- `MarkdownWKWebView` struct (lines 413–1150+)
- Ink dependency → swift-markdown
- HTML/CSS/JS rendering → NSAttributedString + NSTextView

---

## Task 1: Add swift-markdown Dependency

**Files:**
- Modify: `Package.swift`

**Step 1: Add the dependency**

```swift
dependencies: [
    .package(url: "https://github.com/apple/swift-markdown.git", from: "0.4.0"),
    // Remove Ink if no longer needed elsewhere
],
targets: [
    .executableTarget(
        name: "PlanReview",
        dependencies: [
            .product(name: "Markdown", package: "swift-markdown"),
        ]
    ),
]
```

**Step 2: Verify it builds**

Run: `swift build`
Expected: Build succeeds with new dependency resolved.

**Step 3: Commit**

```bash
git add Package.swift Package.resolved
git commit -m "deps: add swift-markdown, prepare to remove Ink"
```

---

## Task 2: Create MarkdownTheme for Styling

**Files:**
- Create: `Sources/Markdown/MarkdownTheme.swift`

**Step 1: Define the theme struct**

This centralizes all styling decisions (fonts, colors, spacing) matching the current CSS.

```swift
import AppKit

struct MarkdownTheme {
    // MARK: - Fonts
    var baseFont: NSFont { .systemFont(ofSize: 14) }
    var boldFont: NSFont { .boldSystemFont(ofSize: 14) }
    var italicFont: NSFont { NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask) }
    var codeFont: NSFont { .monospacedSystemFont(ofSize: 13, weight: .regular) }
    
    func headingFont(level: Int) -> NSFont {
        let sizes: [CGFloat] = [28, 24, 20, 18, 16, 14]
        let size = sizes[min(level - 1, sizes.count - 1)]
        return .boldSystemFont(ofSize: size)
    }
    
    // MARK: - Colors (Dark mode friendly)
    var textColor: NSColor { .labelColor }
    var secondaryTextColor: NSColor { .secondaryLabelColor }
    var linkColor: NSColor { .linkColor }
    var codeBackgroundColor: NSColor { NSColor(white: 0.15, alpha: 1.0) }
    var commentHighlightColor: NSColor { NSColor.yellow.withAlphaComponent(0.3) }
    
    // MARK: - Spacing
    var paragraphSpacing: CGFloat { 12 }
    var headingSpacingBefore: CGFloat { 16 }
    var headingSpacingAfter: CGFloat { 8 }
    var listIndent: CGFloat { 20 }
    var codeBlockPadding: CGFloat { 8 }
}
```

**Step 2: Commit**

```bash
git add Sources/Markdown/MarkdownTheme.swift
git commit -m "feat: add MarkdownTheme for native text styling"
```

---

## Task 3: Build Markdown → NSAttributedString Renderer

**Files:**
- Create: `Sources/Markdown/MarkdownRenderer.swift`

**Step 1: Implement the MarkupVisitor**

This walks the swift-markdown AST and builds an attributed string.

```swift
import AppKit
import Markdown

struct MarkdownRenderer: MarkupVisitor {
    typealias Result = NSAttributedString
    
    let theme: MarkdownTheme
    
    init(theme: MarkdownTheme = MarkdownTheme()) {
        self.theme = theme
    }
    
    // MARK: - Entry Point
    func render(_ markdown: String) -> NSAttributedString {
        let document = Document(parsing: markdown)
        return visit(document)
    }
    
    // MARK: - Default (recurse children)
    mutating func defaultVisit(_ markup: Markup) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for child in markup.children {
            result.append(visit(child))
        }
        return result
    }
    
    // MARK: - Text
    mutating func visitText(_ text: Text) -> NSAttributedString {
        NSAttributedString(string: text.string, attributes: [
            .font: theme.baseFont,
            .foregroundColor: theme.textColor
        ])
    }
    
    // MARK: - Strong (Bold)
    mutating func visitStrong(_ strong: Strong) -> NSAttributedString {
        let content = defaultVisit(strong).mutableCopy() as! NSMutableAttributedString
        content.addAttribute(.font, value: theme.boldFont, range: NSRange(location: 0, length: content.length))
        return content
    }
    
    // MARK: - Emphasis (Italic)
    mutating func visitEmphasis(_ emphasis: Emphasis) -> NSAttributedString {
        let content = defaultVisit(emphasis).mutableCopy() as! NSMutableAttributedString
        content.addAttribute(.font, value: theme.italicFont, range: NSRange(location: 0, length: content.length))
        return content
    }
    
    // MARK: - Headings
    mutating func visitHeading(_ heading: Heading) -> NSAttributedString {
        let content = defaultVisit(heading).mutableCopy() as! NSMutableAttributedString
        let font = theme.headingFont(level: heading.level)
        content.addAttribute(.font, value: font, range: NSRange(location: 0, length: content.length))
        
        let style = NSMutableParagraphStyle()
        style.paragraphSpacingBefore = theme.headingSpacingBefore
        style.paragraphSpacing = theme.headingSpacingAfter
        content.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: content.length))
        
        content.append(NSAttributedString(string: "\n"))
        return content
    }
    
    // MARK: - Paragraphs
    mutating func visitParagraph(_ paragraph: Paragraph) -> NSAttributedString {
        let content = defaultVisit(paragraph).mutableCopy() as! NSMutableAttributedString
        
        let style = NSMutableParagraphStyle()
        style.paragraphSpacing = theme.paragraphSpacing
        content.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: content.length))
        
        content.append(NSAttributedString(string: "\n"))
        return content
    }
    
    // MARK: - Inline Code
    mutating func visitInlineCode(_ inlineCode: InlineCode) -> NSAttributedString {
        NSAttributedString(string: inlineCode.code, attributes: [
            .font: theme.codeFont,
            .foregroundColor: theme.textColor,
            .backgroundColor: theme.codeBackgroundColor
        ])
    }
    
    // MARK: - Code Blocks
    mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> NSAttributedString {
        let code = codeBlock.code.trimmingCharacters(in: .newlines)
        
        let style = NSMutableParagraphStyle()
        style.headIndent = theme.codeBlockPadding
        style.firstLineHeadIndent = theme.codeBlockPadding
        style.paragraphSpacing = theme.paragraphSpacing
        
        let result = NSMutableAttributedString(string: code + "\n\n", attributes: [
            .font: theme.codeFont,
            .foregroundColor: theme.textColor,
            .backgroundColor: theme.codeBackgroundColor,
            .paragraphStyle: style
        ])
        return result
    }
    
    // MARK: - Links
    mutating func visitLink(_ link: Link) -> NSAttributedString {
        let content = defaultVisit(link).mutableCopy() as! NSMutableAttributedString
        if let destination = link.destination, let url = URL(string: destination) {
            content.addAttribute(.link, value: url, range: NSRange(location: 0, length: content.length))
            content.addAttribute(.foregroundColor, value: theme.linkColor, range: NSRange(location: 0, length: content.length))
        }
        return content
    }
    
    // MARK: - Lists
    mutating func visitUnorderedList(_ list: UnorderedList) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for item in list.listItems {
            let bullet = NSAttributedString(string: "• ", attributes: [.font: theme.baseFont])
            let content = defaultVisit(item).mutableCopy() as! NSMutableAttributedString
            
            let style = NSMutableParagraphStyle()
            style.headIndent = theme.listIndent
            style.firstLineHeadIndent = 0
            content.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: content.length))
            
            result.append(bullet)
            result.append(content)
        }
        return result
    }
    
    mutating func visitOrderedList(_ list: OrderedList) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for (index, item) in list.listItems.enumerated() {
            let number = NSAttributedString(string: "\(index + 1). ", attributes: [.font: theme.baseFont])
            let content = defaultVisit(item).mutableCopy() as! NSMutableAttributedString
            
            let style = NSMutableParagraphStyle()
            style.headIndent = theme.listIndent
            style.firstLineHeadIndent = 0
            content.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: content.length))
            
            result.append(number)
            result.append(content)
        }
        return result
    }
    
    // MARK: - Blockquotes
    mutating func visitBlockQuote(_ blockQuote: BlockQuote) -> NSAttributedString {
        let content = defaultVisit(blockQuote).mutableCopy() as! NSMutableAttributedString
        
        let style = NSMutableParagraphStyle()
        style.headIndent = theme.listIndent
        style.firstLineHeadIndent = theme.listIndent
        
        content.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: content.length))
        content.addAttribute(.foregroundColor, value: theme.secondaryTextColor, range: NSRange(location: 0, length: content.length))
        
        return content
    }
    
    // MARK: - Thematic Break (Horizontal Rule)
    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) -> NSAttributedString {
        NSAttributedString(string: "\n─────────────────────────\n\n", attributes: [
            .font: theme.baseFont,
            .foregroundColor: theme.secondaryTextColor
        ])
    }
    
    // MARK: - Tables (Monospaced rendering)
    mutating func visitTable(_ table: Table) -> NSAttributedString {
        // Render tables in monospaced font for alignment
        var rows: [[String]] = []
        
        // Collect header
        if let head = table.head {
            var headerRow: [String] = []
            for cell in head.cells {
                headerRow.append(cell.plainText)
            }
            rows.append(headerRow)
        }
        
        // Collect body rows
        for row in table.body.rows {
            var bodyRow: [String] = []
            for cell in row.cells {
                bodyRow.append(cell.plainText)
            }
            rows.append(bodyRow)
        }
        
        // Calculate column widths
        var widths: [Int] = []
        for row in rows {
            for (i, cell) in row.enumerated() {
                if i >= widths.count {
                    widths.append(cell.count)
                } else {
                    widths[i] = max(widths[i], cell.count)
                }
            }
        }
        
        // Build table string
        var tableString = ""
        for (rowIndex, row) in rows.enumerated() {
            var line = "| "
            for (i, cell) in row.enumerated() {
                let padded = cell.padding(toLength: widths[i], withPad: " ", startingAt: 0)
                line += padded + " | "
            }
            tableString += line.trimmingCharacters(in: .whitespaces) + "\n"
            
            // Add separator after header
            if rowIndex == 0 {
                var sep = "| "
                for width in widths {
                    sep += String(repeating: "-", count: width) + " | "
                }
                tableString += sep.trimmingCharacters(in: .whitespaces) + "\n"
            }
        }
        tableString += "\n"
        
        return NSAttributedString(string: tableString, attributes: [
            .font: theme.codeFont,
            .foregroundColor: theme.textColor
        ])
    }
}
```

**Step 2: Commit**

```bash
git add Sources/Markdown/MarkdownRenderer.swift
git commit -m "feat: add MarkdownRenderer using swift-markdown visitor"
```

---

## Task 4: Create NSTextView Wrapper (NSViewRepresentable)

**Files:**
- Create: `Sources/Markdown/MarkdownTextView.swift`

**Step 1: Implement the wrapper**

```swift
import SwiftUI
import AppKit

struct MarkdownTextView: NSViewRepresentable {
    let attributedString: NSAttributedString
    let onSelectionChange: ((NSRange, String) -> Void)?
    let onLinkClick: ((URL) -> Void)?
    
    init(
        attributedString: NSAttributedString,
        onSelectionChange: ((NSRange, String) -> Void)? = nil,
        onLinkClick: ((URL) -> Void)? = nil
    ) {
        self.attributedString = attributedString
        self.onSelectionChange = onSelectionChange
        self.onLinkClick = onLinkClick
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        
        // Create NSTextView with TextKit 2
        let textView = NSTextView(usingTextLayoutManager: true)
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 16, height: 16)
        textView.isAutomaticLinkDetectionEnabled = true
        textView.delegate = context.coordinator
        
        // Configure for smooth scrolling
        textView.layoutManager?.allowsNonContiguousLayout = true
        
        scrollView.documentView = textView
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        
        // Only update if content changed
        if textView.attributedString() != attributedString {
            textView.textStorage?.setAttributedString(attributedString)
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
        
        func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
            if let url = link as? URL {
                parent.onLinkClick?(url)
                return true
            }
            return false
        }
    }
}
```

**Step 2: Commit**

```bash
git add Sources/Markdown/MarkdownTextView.swift
git commit -m "feat: add MarkdownTextView NSViewRepresentable wrapper"
```

---

## Task 5: Add Comment Highlighting Support

**Files:**
- Create: `Sources/Markdown/CommentHighlighter.swift`

**Step 1: Implement highlighter**

This applies background color to ranges matching comment selections.

```swift
import AppKit

struct CommentHighlighter {
    let theme: MarkdownTheme
    
    init(theme: MarkdownTheme = MarkdownTheme()) {
        self.theme = theme
    }
    
    /// Applies comment highlights to an attributed string
    /// - Parameters:
    ///   - attributedString: The base attributed string
    ///   - comments: Array of comments with selectedText
    /// - Returns: New attributed string with highlights applied
    func applyHighlights(
        to attributedString: NSAttributedString,
        comments: [Comment]
    ) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: attributedString)
        let fullText = mutable.string as NSString
        
        for comment in comments {
            guard !comment.selectedText.isEmpty else { continue }
            
            // Find all occurrences of the selected text
            var searchRange = NSRange(location: 0, length: fullText.length)
            
            while searchRange.location < fullText.length {
                let foundRange = fullText.range(of: comment.selectedText, options: [], range: searchRange)
                
                if foundRange.location == NSNotFound {
                    break
                }
                
                // Apply highlight
                mutable.addAttribute(
                    .backgroundColor,
                    value: theme.commentHighlightColor,
                    range: foundRange
                )
                
                // Move search forward
                searchRange.location = foundRange.location + foundRange.length
                searchRange.length = fullText.length - searchRange.location
            }
        }
        
        return mutable
    }
}
```

**Step 2: Commit**

```bash
git add Sources/Markdown/CommentHighlighter.swift
git commit -m "feat: add CommentHighlighter for marking commented text"
```

---

## Task 6: Integrate into ContentView

**Files:**
- Modify: `Sources/ContentView.swift`

**Step 1: Replace MarkdownWKWebView usage**

Find where `MarkdownWKWebView` is instantiated and replace with:

```swift
// Before (remove this):
// MarkdownWKWebView(markdown: plan.content, comments: comments, ...)

// After:
let renderer = MarkdownRenderer()
let baseAttributed = renderer.render(plan.content)
let highlighter = CommentHighlighter()
let highlighted = highlighter.applyHighlights(to: baseAttributed, comments: comments)

MarkdownTextView(
    attributedString: highlighted,
    onSelectionChange: { range, text in
        // Handle selection for new comment creation
        selectedText = text
    },
    onLinkClick: { url in
        NSWorkspace.shared.open(url)
    }
)
```

**Step 2: Remove old MarkdownWKWebView struct**

Delete or comment out the `MarkdownWKWebView` struct (lines ~413–1150) once the new implementation is working.

**Step 3: Remove Ink dependency if no longer needed**

Update `Package.swift` to remove Ink.

**Step 4: Commit**

```bash
git add Sources/ContentView.swift Package.swift
git commit -m "feat: switch from WKWebView to native NSTextView rendering"
```

---

## Task 7: Handle Task Lists (Checkboxes)

**Files:**
- Modify: `Sources/Markdown/MarkdownRenderer.swift`

The current WKWebView manually replaces `[ ]` and `[x]` patterns. We need to handle these in the renderer.

**Step 1: Add ListItem visitor with checkbox detection**

```swift
mutating func visitListItem(_ listItem: ListItem) -> NSAttributedString {
    let content = defaultVisit(listItem)
    let text = content.string
    
    // Check for task list markers
    if text.hasPrefix("[ ] ") || text.hasPrefix("[x] ") || text.hasPrefix("[X] ") {
        let isChecked = text.hasPrefix("[x]") || text.hasPrefix("[X]")
        let checkbox = isChecked ? "☑ " : "☐ "
        let remainder = String(text.dropFirst(4))
        
        let result = NSMutableAttributedString(string: checkbox, attributes: [
            .font: theme.baseFont,
            .foregroundColor: isChecked ? theme.secondaryTextColor : theme.textColor
        ])
        result.append(NSAttributedString(string: remainder, attributes: [
            .font: theme.baseFont,
            .foregroundColor: theme.textColor
        ]))
        return result
    }
    
    return content
}
```

**Step 2: Commit**

```bash
git add Sources/Markdown/MarkdownRenderer.swift
git commit -m "feat: add task list checkbox rendering"
```

---

## Task 8: Testing and Verification

**Files:**
- Optional: Create `Tests/PlanReviewTests/MarkdownRendererTests.swift`

**Manual Verification Checklist:**

1. [ ] Headings render at correct sizes (H1 largest → H6 smallest)
2. [ ] Bold and italic text display correctly
3. [ ] Code blocks have monospaced font and background
4. [ ] Inline code has background highlight
5. [ ] Links are clickable and open in browser
6. [ ] Unordered lists show bullets
7. [ ] Ordered lists show numbers
8. [ ] Blockquotes are indented and dimmed
9. [ ] Tables render with aligned columns
10. [ ] Task lists show checkboxes (☐ / ☑)
11. [ ] Comment highlights appear on commented text
12. [ ] Text selection works for creating new comments
13. [ ] Scroll position is preserved on content updates

**Step 1: Test with sample markdown**

Create a test file with all markdown features and verify rendering.

**Step 2: Commit any fixes**

```bash
git add -A
git commit -m "fix: address rendering issues found in testing"
```

---

## Task 9: Cleanup and Final Polish

**Files:**
- Modify: `Sources/ContentView.swift`
- Delete: Remove Ink-related code

**Steps:**

1. Remove all WKWebView-related code
2. Remove Ink from Package.swift
3. Clean up unused CSS/JS string literals
4. Run `swift build` to verify no errors
5. Final commit

```bash
git add -A
git commit -m "chore: remove WKWebView and Ink, migration complete"
```

---

## Summary

| Task | Description | Estimated Effort |
|------|-------------|------------------|
| 1 | Add swift-markdown dependency | 5 min |
| 2 | Create MarkdownTheme | 15 min |
| 3 | Build MarkdownRenderer (visitor) | 45 min |
| 4 | Create MarkdownTextView wrapper | 30 min |
| 5 | Add CommentHighlighter | 20 min |
| 6 | Integrate into ContentView | 30 min |
| 7 | Handle task lists | 15 min |
| 8 | Testing and verification | 30 min |
| 9 | Cleanup | 15 min |

**Total:** ~3.5 hours

---

## Future Enhancements (Out of Scope)

- **Syntax highlighting for code blocks:** Add Highlightr integration
- **Editable mode:** Allow users to edit markdown directly in NSTextView
- **Images:** Support inline images via NSTextAttachment
- **Custom blockquote rendering:** Add vertical accent bar via NSTextLayoutFragment
