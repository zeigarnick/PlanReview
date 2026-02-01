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
        var visitor = self
        return visitor.visit(document)
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
        let style = NSMutableParagraphStyle()
        style.lineSpacing = theme.lineSpacing
        
        return NSAttributedString(string: text.string, attributes: [
            .font: theme.baseFont,
            .foregroundColor: theme.textColor,
            .paragraphStyle: style
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
        style.lineSpacing = theme.lineSpacing
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
            let bullet = NSAttributedString(string: "• ", attributes: [
                .font: theme.baseFont,
                .foregroundColor: theme.textColor
            ])
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
            let number = NSAttributedString(string: "\(index + 1). ", attributes: [
                .font: theme.baseFont,
                .foregroundColor: theme.textColor
            ])
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
    
    // MARK: - List Items (Task Lists)
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
        NSAttributedString(string: "\n\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\n\n", attributes: [
            .font: theme.baseFont,
            .foregroundColor: theme.secondaryTextColor
        ])
    }
    
    // MARK: - Tables (Visual rendering with NSTextTable)
    mutating func visitTable(_ table: Table) -> NSAttributedString {
        let result = NSMutableAttributedString()
        
        // Collect all rows (header + body)
        var allRows: [(cells: [String], isHeader: Bool)] = []
        
        // Header row
        let head = table.head
        var headerCells: [String] = []
        for cell in head.cells {
            headerCells.append(cell.plainText)
        }
        allRows.append((cells: headerCells, isHeader: true))
        
        // Body rows
        for row in table.body.rows {
            var bodyCells: [String] = []
            for cell in row.cells {
                bodyCells.append(cell.plainText)
            }
            allRows.append((cells: bodyCells, isHeader: false))
        }
        
        guard !allRows.isEmpty, let columnCount = allRows.first?.cells.count, columnCount > 0 else {
            return result
        }
        
        // Create NSTextTable
        let textTable = NSTextTable()
        textTable.numberOfColumns = columnCount
        textTable.setContentWidth(100, type: .percentageValueType)
        textTable.hidesEmptyCells = false
        
        // Table border styling
        let borderColor = NSColor.separatorColor
        
        // Build each cell
        for (rowIndex, rowData) in allRows.enumerated() {
            for (colIndex, cellText) in rowData.cells.enumerated() {
                // Create text block for this cell
                let textBlock = NSTextTableBlock(table: textTable, startingRow: rowIndex, rowSpan: 1, startingColumn: colIndex, columnSpan: 1)
                
                // Cell styling
                textBlock.setWidth(0.5, type: .absoluteValueType, for: .border)
                textBlock.setBorderColor(borderColor)
                textBlock.setWidth(8, type: .absoluteValueType, for: .padding)
                
                // Alternating row background (skip header)
                if rowData.isHeader {
                    textBlock.backgroundColor = NSColor(white: 0.15, alpha: 1.0)
                } else if rowIndex % 2 == 0 {
                    textBlock.backgroundColor = NSColor(white: 0.12, alpha: 1.0)
                } else {
                    textBlock.backgroundColor = NSColor(white: 0.10, alpha: 1.0)
                }
                
                // Create paragraph style with the text block
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.textBlocks = [textBlock]
                
                // Font based on header or body
                let font: NSFont
                if rowData.isHeader {
                    font = theme.boldFont
                } else {
                    font = theme.baseFont
                }
                
                // Build cell content (add newline to complete the cell)
                let cellContent = cellText + "\n"
                let cellAttributedString = NSMutableAttributedString(string: cellContent, attributes: [
                    .font: font,
                    .foregroundColor: theme.textColor,
                    .paragraphStyle: paragraphStyle
                ])
                
                result.append(cellAttributedString)
            }
        }
        
        // Add trailing newline for spacing after table
        result.append(NSAttributedString(string: "\n"))
        
        return result
    }
}
