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
