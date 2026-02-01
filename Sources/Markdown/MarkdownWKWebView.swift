import SwiftUI
import WebKit
import Ink

// MARK: - WKWebView Markdown Renderer (Matches Original Binary Exactly)

struct MarkdownWKWebView: NSViewRepresentable {
    let markdown: String
    let comments: [Comment]
    let onSelectionChange: ((String, CGRect, Int) -> Void)?  // Added charOffset
    let onCommentClick: ((String, CGRect) -> Void)?
    let onAddComment: ((String) -> Void)?
    
    init(
        markdown: String,
        comments: [Comment] = [],
        onSelectionChange: ((String, CGRect, Int) -> Void)? = nil,
        onCommentClick: ((String, CGRect) -> Void)? = nil,
        onAddComment: ((String) -> Void)? = nil
    ) {
        self.markdown = markdown
        self.comments = comments
        self.onSelectionChange = onSelectionChange
        self.onCommentClick = onCommentClick
        self.onAddComment = onAddComment
    }
    
    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "editor")
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        
        // Transparent background
        webView.setValue(false, forKey: "drawsBackground")
        
        #if DEBUG
        webView.configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
        #endif
        
        context.coordinator.webView = webView
        
        let html = generateHTML(markdown: markdown, comments: comments)
        webView.loadHTMLString(html, baseURL: nil)
        
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        let commentsJSON = commentsToJSON(comments)
        webView.evaluateJavaScript("window.setComments && window.setComments(\(commentsJSON));", completionHandler: nil)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // MARK: - HTML Generation (Exact Match to Original Binary)
    
    private func generateHTML(markdown: String, comments: [Comment]) -> String {
        let parser = MarkdownParser()
        var html = parser.html(from: markdown)
        html = processTaskLists(html)
        
        let commentsJSON = commentsToJSON(comments)
        
        return """
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        @import url('https://fonts.googleapis.com/css2?family=Geist:wght@400;500;600;700&family=Geist+Mono:wght@400;500&display=swap');
        
        * { margin: 0; padding: 0; box-sizing: border-box; }
        
        body {
            font-family: 'Geist', -apple-system, sans-serif;
            font-size: 14px;
            line-height: 1.6;
            color: #c9c9c9;
            background: #1a1a1a;
            padding: 32px 64px 100px;
            min-height: 100vh;
        }
        
        #content { max-width: 760px; outline: none; }
        #content:focus { outline: none; }
        
        h1, h2, h3, h4, h5, h6 {
            color: #fff;
            font-weight: 600;
            margin-top: 20px;
            margin-bottom: 8px;
            line-height: 1.3;
        }
        h1 { font-size: 1.75em; font-weight: 700; margin-top: 0; margin-bottom: 16px; }
        h2 { font-size: 1.35em; }
        h3 { font-size: 1.15em; }
        
        p { margin-bottom: 12px; }
        
        ul, ol { margin-bottom: 12px; padding-left: 20px; }
        li { margin-bottom: 4px; }
        li::marker { color: #666; }
        
        /* Task list */
        li.task { list-style: none; margin-left: -20px; }
        input[type="checkbox"] {
            appearance: none; -webkit-appearance: none;
            width: 14px; height: 14px;
            border: 1.5px solid #555; border-radius: 3px;
            margin-right: 8px; vertical-align: middle;
            position: relative; top: -1px; cursor: pointer;
        }
        input[type="checkbox"]:checked {
            background: #3b82f6; border-color: #3b82f6;
        }
        input[type="checkbox"]:checked::after {
            content: '✓'; color: white; font-size: 10px;
            position: absolute; top: 50%; left: 50%;
            transform: translate(-50%, -50%);
        }
        
        /* Tables */
        table { width: 100%; border-collapse: collapse; margin: 12px 0; font-size: 13px; }
        th, td { padding: 8px 12px; text-align: left; border: 1px solid #333; }
        th { background: rgba(255,255,255,0.05); font-weight: 600; color: #fff; }
        tr:nth-child(even) { background: rgba(255,255,255,0.02); }
        
        /* Code */
        code {
            font-family: 'Geist Mono', monospace;
            font-size: 0.9em; background: rgba(255,255,255,0.08);
            padding: 2px 6px; border-radius: 4px; color: #f0a67a;
        }
        pre {
            background: #0d0d0d; border-radius: 6px;
            padding: 12px 16px; margin: 12px 0;
            overflow-x: auto; border: 1px solid rgba(255,255,255,0.08);
        }
        pre code {
            background: transparent; padding: 0;
            color: #d4d4d4; font-size: 13px; line-height: 1.5;
        }
        
        strong { font-weight: 600; color: #fff; }
        em { font-style: italic; }
        a { color: #60a5fa; text-decoration: none; }
        a:hover { text-decoration: underline; }
        blockquote { border-left: 3px solid #444; padding-left: 16px; margin: 12px 0; color: #888; }
        hr { border: none; border-top: 1px solid rgba(255,255,255,0.1); margin: 20px 0; }
        ::selection { background: rgba(96,165,250,0.4); }
        
        /* Comment highlights */
        .comment-highlight {
            background: rgba(251, 191, 36, 0.2);
            border-bottom: 2px solid rgba(251, 191, 36, 0.6);
            cursor: pointer;
            position: relative;
        }
        .comment-highlight:hover {
            background: rgba(251, 191, 36, 0.35);
        }
        @keyframes pulse {
            0% { background: rgba(251, 191, 36, 0.5); }
            100% { background: rgba(251, 191, 36, 0.2); }
        }
    </style>
</head>
<body>
    <div id="content">\(html)</div>
    <script>
        const content = document.getElementById('content');
        let comments = \(commentsJSON);
        let debounceTimer;
        
        // Allow updating comments from Swift without full reload
        window.setComments = (newComments) => {
            console.log('[DEBUG] setComments called with', newComments.length, 'comments');
            comments = newComments;
            highlightComments();
        };
        
        // Get character offset of a node within content
        function getCharOffset(node, offset) {
            const walker = document.createTreeWalker(content, NodeFilter.SHOW_TEXT, null, false);
            let charCount = 0;
            let current;
            while (current = walker.nextNode()) {
                if (current === node) {
                    return charCount + offset;
                }
                charCount += current.textContent.length;
            }
            return charCount;
        }
        
        // Normalize text for matching (collapse whitespace)
        function normalizeText(text) {
            return text.replace(/\\s+/g, ' ').trim();
        }
        
        // Find range for text at specific character offset
        function findRangeForText(searchText, targetOffset) {
            if (!searchText) return null;
            
            const normalizedSearch = normalizeText(searchText);
            console.log('[DEBUG] findRangeForText:', normalizedSearch.substring(0, 40), 'targetOffset:', targetOffset);
            
            const walker = document.createTreeWalker(content, NodeFilter.SHOW_TEXT, null, false);
            let node;
            const textNodes = [];
            let fullText = '';
            let normalizedFull = '';
            
            while (node = walker.nextNode()) {
                const nodeText = node.textContent;
                const normalizedNode = normalizeText(nodeText);
                
                if (normalizedFull.length > 0 && normalizedNode.length > 0) {
                    normalizedFull += ' ';
                }
                
                textNodes.push({
                    node: node,
                    text: nodeText,
                    normStart: normalizedFull.length,
                    normEnd: normalizedFull.length + normalizedNode.length,
                    rawStart: fullText.length,
                    rawEnd: fullText.length + nodeText.length
                });
                
                fullText += nodeText;
                normalizedFull += normalizedNode;
            }
            
            // Find ALL occurrences and pick the one closest to targetOffset
            let bestMatch = null;
            let bestDistance = Infinity;
            let searchStart = 0;
            
            while (true) {
                const normStartIndex = normalizedFull.indexOf(normalizedSearch, searchStart);
                if (normStartIndex < 0) break;
                
                // Calculate the raw character position for this match
                let rawPos = 0;
                for (const info of textNodes) {
                    if (info.normEnd > normStartIndex) {
                        rawPos = info.rawStart + (normStartIndex - info.normStart);
                        break;
                    }
                }
                
                const distance = Math.abs(rawPos - targetOffset);
                console.log('[DEBUG] Found occurrence at normIdx:', normStartIndex, 'rawPos:', rawPos, 'distance:', distance);
                
                if (distance < bestDistance) {
                    bestDistance = distance;
                    bestMatch = { normStartIndex, normEndIndex: normStartIndex + normalizedSearch.length };
                }
                
                searchStart = normStartIndex + 1;
            }
            
            if (!bestMatch) {
                console.log('[DEBUG] No match found');
                return null;
            }
            
            const { normStartIndex, normEndIndex } = bestMatch;
            console.log('[DEBUG] Best match at', normStartIndex, 'to', normEndIndex, 'distance:', bestDistance);
            
            let startNode, startOffset, endNode, endOffset;
            
            for (const info of textNodes) {
                if (!startNode && info.normEnd > normStartIndex) {
                    startNode = info.node;
                    const normOffset = normStartIndex - info.normStart;
                    startOffset = mapNormOffsetToRaw(info.text, normOffset);
                }
                
                if (startNode && info.normEnd >= normEndIndex) {
                    endNode = info.node;
                    const normOffset = normEndIndex - info.normStart;
                    endOffset = mapNormOffsetToRaw(info.text, normOffset);
                    break;
                }
            }
            
            if (!startNode || !endNode) {
                console.log('[DEBUG] Could not find nodes for range');
                return null;
            }
            
            try {
                const range = document.createRange();
                range.setStart(startNode, Math.min(startOffset, startNode.textContent.length));
                range.setEnd(endNode, Math.min(endOffset, endNode.textContent.length));
                return range;
            } catch (e) {
                console.log('[DEBUG] Range creation error:', e);
                return null;
            }
        }
        
        function mapNormOffsetToRaw(text, normOffset) {
            let rawIdx = 0;
            let normIdx = 0;
            let inWhitespace = true;
            
            for (let i = 0; i < text.length && normIdx < normOffset; i++) {
                const isSpace = /\\s/.test(text[i]);
                if (isSpace) {
                    if (!inWhitespace) {
                        normIdx++;
                        inWhitespace = true;
                    }
                } else {
                    normIdx++;
                    inWhitespace = false;
                }
                rawIdx = i + 1;
            }
            
            return rawIdx;
        }
        
        function highlightComments() {
            console.log('[DEBUG] highlightComments called, comments:', comments.length);
            
            document.querySelectorAll('.comment-highlight').forEach(el => {
                const parent = el.parentNode;
                while (el.firstChild) {
                    parent.insertBefore(el.firstChild, el);
                }
                parent.removeChild(el);
            });
            content.normalize();
            
            comments.forEach((comment, i) => {
                console.log('[DEBUG] Processing comment', i, 'selectedText:', comment.selectedText?.substring(0, 30), 'charOffset:', comment.charOffset);
                if (!comment.selectedText) {
                    console.log('[DEBUG] Skipping - no selectedText');
                    return;
                }
                
                const range = findRangeForText(comment.selectedText, comment.charOffset || 0);
                if (!range) {
                    console.log('[DEBUG] Skipping - no range found');
                    return;
                }
                
                try {
                    const span = document.createElement('span');
                    span.className = 'comment-highlight';
                    span.dataset.commentId = comment.id;
                    range.surroundContents(span);
                    console.log('[DEBUG] Highlight created successfully');
                } catch (e) {
                    console.log('[DEBUG] surroundContents failed, using fallback:', e.message);
                    try {
                        highlightRangeWithSpans(range, comment.id);
                    } catch (e2) {
                        console.log('[DEBUG] Fallback also failed:', e2.message);
                    }
                }
            });
        }
        
        function highlightRangeWithSpans(range, commentId) {
            const startContainer = range.startContainer;
            const endContainer = range.endContainer;
            const startOffset = range.startOffset;
            const endOffset = range.endOffset;
            
            if (startContainer === endContainer && startContainer.nodeType === Node.TEXT_NODE) {
                const text = startContainer.textContent;
                const before = text.substring(0, startOffset);
                const middle = text.substring(startOffset, endOffset);
                const after = text.substring(endOffset);
                
                const span = document.createElement('span');
                span.className = 'comment-highlight';
                span.dataset.commentId = commentId;
                span.textContent = middle;
                
                const parent = startContainer.parentNode;
                if (before) parent.insertBefore(document.createTextNode(before), startContainer);
                parent.insertBefore(span, startContainer);
                if (after) parent.insertBefore(document.createTextNode(after), startContainer);
                parent.removeChild(startContainer);
                return;
            }
            
            const nodesToWrap = [];
            const walker = document.createTreeWalker(range.commonAncestorContainer, NodeFilter.SHOW_TEXT);
            let node;
            let inRange = false;
            
            while (node = walker.nextNode()) {
                if (node === startContainer) inRange = true;
                if (inRange) nodesToWrap.push(node);
                if (node === endContainer) break;
            }
            
            nodesToWrap.forEach((textNode, idx) => {
                let start = 0, end = textNode.textContent.length;
                if (textNode === startContainer) start = startOffset;
                if (textNode === endContainer) end = endOffset;
                
                if (start === 0 && end === textNode.textContent.length) {
                    const span = document.createElement('span');
                    span.className = 'comment-highlight';
                    span.dataset.commentId = commentId;
                    textNode.parentNode.insertBefore(span, textNode);
                    span.appendChild(textNode);
                } else {
                    const text = textNode.textContent;
                    const before = text.substring(0, start);
                    const middle = text.substring(start, end);
                    const after = text.substring(end);
                    
                    const span = document.createElement('span');
                    span.className = 'comment-highlight';
                    span.dataset.commentId = commentId;
                    span.textContent = middle;
                    
                    const parent = textNode.parentNode;
                    if (before) parent.insertBefore(document.createTextNode(before), textNode);
                    parent.insertBefore(span, textNode);
                    if (after) parent.insertBefore(document.createTextNode(after), textNode);
                    parent.removeChild(textNode);
                }
            });
        }
        
        function scrollToComment(commentId) {
            const el = document.querySelector('[data-comment-id="' + commentId + '"]');
            if (el) {
                el.scrollIntoView({ behavior: 'smooth', block: 'center' });
                el.style.animation = 'pulse 0.5s ease-out';
                setTimeout(() => el.style.animation = '', 500);
            }
        }
        
        function editComment(commentId, rect) {
            window.webkit.messageHandlers.editor.postMessage({ 
                type: 'editComment', 
                commentId: commentId,
                rect: rect
            });
        }
        
        function deleteComment(commentId) {
            window.webkit.messageHandlers.editor.postMessage({ 
                type: 'deleteComment', 
                commentId: commentId 
            });
        }
        
        // Use mousedown - normalize target in case it's a text node
        content.addEventListener('mousedown', (e) => {
            const target = e.target.nodeType === Node.TEXT_NODE ? e.target.parentElement : e.target;
            const highlight = target?.closest('.comment-highlight');
            if (!highlight) return;
            
            e.preventDefault();
            e.stopPropagation();
            
            const commentId = highlight.dataset.commentId;
            const rect = highlight.getBoundingClientRect();
            editComment(commentId, { x: rect.x, y: rect.y, width: rect.width, height: rect.height });
        }, true);
        
        document.addEventListener('mouseup', () => {
            console.log('[DEBUG] mouseup fired');
            setTimeout(() => {
                const sel = window.getSelection();
                const text = sel.toString().trim();
                console.log('[DEBUG] selection text:', text);
                if (text && sel.rangeCount > 0) {
                    const range = sel.getRangeAt(0);
                    const rect = range.getBoundingClientRect();
                    const charOffset = getCharOffset(range.startContainer, range.startOffset);
                    console.log('[DEBUG] sending selection message', rect, 'charOffset:', charOffset);
                    window.webkit.messageHandlers.editor.postMessage({
                        type: 'selection', text,
                        rect: { x: rect.x, y: rect.y, width: rect.width, height: rect.height },
                        charOffset: charOffset
                    });
                } else {
                    window.webkit.messageHandlers.editor.postMessage({
                        type: 'selection', text: '', rect: { x: 0, y: 0, width: 0, height: 0 }, charOffset: 0
                    });
                }
            }, 10);
        });
        
        document.addEventListener('keydown', e => {
            if (e.metaKey && e.key === 'k') {
                e.preventDefault();
                const text = window.getSelection().toString().trim();
                if (text) {
                    window.webkit.messageHandlers.editor.postMessage({ type: 'comment', text });
                }
            }
            // Cmd+Enter = Submit/Approve
            if (e.metaKey && !e.shiftKey && e.key === 'Enter') {
                e.preventDefault();
                window.webkit.messageHandlers.editor.postMessage({ type: 'submit' });
            }
            // Cmd+Shift+R = Request Changes
            if (e.metaKey && e.shiftKey && e.key === 'r') {
                e.preventDefault();
                window.webkit.messageHandlers.editor.postMessage({ type: 'requestChanges' });
            }
        });
        
        highlightComments();
    </script>
</body>
</html>
"""
    }
    
    private func processTaskLists(_ html: String) -> String {
        var result = html
        result = result.replacingOccurrences(
            of: "<li>[ ] ",
            with: "<li class=\"task\"><input type=\"checkbox\" disabled> "
        )
        result = result.replacingOccurrences(
            of: "<li>[x] ",
            with: "<li class=\"task\"><input type=\"checkbox\" checked disabled> ",
            options: .caseInsensitive
        )
        return result
    }
    
    private func commentsToJSON(_ comments: [Comment]) -> String {
        let items = comments.map { comment in
            """
            {"id":"\(comment.id.uuidString)","selectedText":"\(escapeJS(comment.selectedText))","charOffset":\(comment.charOffset ?? 0)}
            """
        }
        return "[\(items.joined(separator: ","))]"
    }
    
    private func escapeJS(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let parent: MarkdownWKWebView
        weak var webView: WKWebView?
        
        init(_ parent: MarkdownWKWebView) {
            self.parent = parent
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let dict = message.body as? [String: Any],
                  let type = dict["type"] as? String else { return }
            
            print("[DEBUG] Received message type:", type)
            
            switch type {
            case "selection":
                let text = dict["text"] as? String ?? ""
                let rect = parseRect(dict["rect"])
                let charOffset = dict["charOffset"] as? Int ?? 0
                print("[DEBUG] Selection text: '\(text)' charOffset: \(charOffset)")
                print("[DEBUG] Selection rect:", rect)
                parent.onSelectionChange?(text, rect, charOffset)
                
            case "editComment":
                if let commentId = dict["commentId"] as? String {
                    let rect = parseRect(dict["rect"])
                    parent.onCommentClick?(commentId, rect)
                }
                
            case "comment":
                if let text = dict["text"] as? String {
                    parent.onAddComment?(text)
                }
                
            case "submit":
                // Forward Cmd+Enter to SwiftUI
                NotificationCenter.default.post(name: .triggerSubmit, object: nil)
            
            case "requestChanges":
                // Forward Cmd+Shift+R to SwiftUI
                NotificationCenter.default.post(name: .triggerRequestChanges, object: nil)
                
            case "deleteComment":
                // Handle delete if needed
                break
                
            case "contentChange":
                // Content changed - mark dirty if needed
                break
                
            default:
                break
            }
        }
        
        private func parseRect(_ dict: Any?) -> CGRect {
            guard let rectDict = dict as? [String: Any],
                  let x = rectDict["x"] as? CGFloat,
                  let y = rectDict["y"] as? CGFloat,
                  let width = rectDict["width"] as? CGFloat,
                  let height = rectDict["height"] as? CGFloat else {
                return .zero
            }
            return CGRect(x: x, y: y, width: width, height: height)
        }
        
        func scrollToComment(_ commentId: String) {
            webView?.evaluateJavaScript("scrollToComment('\(commentId)');", completionHandler: nil)
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated {
                if let url = navigationAction.request.url {
                    NSWorkspace.shared.open(url)
                }
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }
    }
}
