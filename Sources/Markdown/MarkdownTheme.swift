import AppKit

struct MarkdownTheme {
    // MARK: - Fonts
    // Try to use Geist font if available, fall back to SF Pro
    var baseFont: NSFont {
        NSFont(name: "Geist-Regular", size: 15) 
            ?? NSFont(name: "SF Pro Text", size: 15)
            ?? .systemFont(ofSize: 15)
    }
    
    var boldFont: NSFont {
        NSFont(name: "Geist-Bold", size: 15)
            ?? NSFont(name: "SF Pro Text Bold", size: 15)
            ?? .boldSystemFont(ofSize: 15)
    }
    
    var italicFont: NSFont {
        NSFont(name: "Geist-Italic", size: 15)
            ?? NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
    }
    
    var codeFont: NSFont {
        NSFont(name: "GeistMono-Regular", size: 14)
            ?? NSFont(name: "SF Mono", size: 14)
            ?? .monospacedSystemFont(ofSize: 14, weight: .regular)
    }
    
    func headingFont(level: Int) -> NSFont {
        let sizes: [CGFloat] = [32, 26, 22, 18, 16, 15]
        let size = sizes[min(level - 1, sizes.count - 1)]
        return NSFont(name: "Geist-Bold", size: size)
            ?? NSFont(name: "SF Pro Display Bold", size: size)
            ?? .boldSystemFont(ofSize: size)
    }
    
    // MARK: - Colors (Dark mode optimized)
    var textColor: NSColor { .labelColor }
    var secondaryTextColor: NSColor { .secondaryLabelColor }
    var linkColor: NSColor { NSColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 1.0) }
    
    // Code block styling - darker background with good contrast
    var codeBackgroundColor: NSColor {
        NSColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1.0)
    }
    var codeBorderColor: NSColor {
        NSColor(white: 0.25, alpha: 1.0)
    }
    
    // Comment highlight - subtle yellow tint
    var commentHighlightColor: NSColor {
        NSColor(red: 1.0, green: 0.9, blue: 0.4, alpha: 0.25)
    }
    
    // MARK: - Spacing (more generous, matches CSS)
    var paragraphSpacing: CGFloat { 16 }
    var lineSpacing: CGFloat { 4 }
    var headingSpacingBefore: CGFloat { 24 }
    var headingSpacingAfter: CGFloat { 12 }
    var listIndent: CGFloat { 24 }
    var codeBlockPadding: CGFloat { 16 }
    var codeBlockCornerRadius: CGFloat { 8 }
    var contentInset: CGFloat { 32 }
}
