import Foundation

enum MarkdownMediaEmbedProcessor {
    static func processEmbeds(in html: String) -> String {
        var result = html
        result = replaceStandaloneWebMLinks(in: result)
        result = replaceStandaloneWebMImages(in: result)
        return result
    }

    private static func replaceStandaloneWebMLinks(in html: String) -> String {
        replaceMatches(
            in: html,
            pattern: #"<p>\s*<a href=\"([^\"]+)\">(.*?)</a>\s*</p>"#
        ) { href, captionHTML in
            guard isWebMURL(href) else { return nil }

            let caption = plainText(fromHTML: captionHTML)
            return inlineVideoHTML(source: href, caption: caption)
        }
    }

    private static func replaceStandaloneWebMImages(in html: String) -> String {
        replaceMatches(
            in: html,
            pattern: #"<p>\s*<img\s+src=\"([^\"]+)\"(?:\s+alt=\"([^\"]*)\")?\s*\/?>\s*</p>"#
        ) { src, altText in
            guard isWebMURL(src) else { return nil }
            return inlineVideoHTML(source: src, caption: altText)
        }
    }

    private static func replaceMatches(
        in html: String,
        pattern: String,
        transform: (_ src: String, _ caption: String) -> String?
    ) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.dotMatchesLineSeparators, .caseInsensitive]
        ) else {
            return html
        }

        let nsString = html as NSString
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: nsString.length))

        guard !matches.isEmpty else { return html }

        let output = NSMutableString(string: html)

        for match in matches.reversed() {
            guard match.numberOfRanges >= 3 else { continue }

            let fullRange = match.range(at: 0)
            let sourceRange = match.range(at: 1)
            let captionRange = match.range(at: 2)

            guard sourceRange.location != NSNotFound else { continue }

            let source = nsString.substring(with: sourceRange)
            let caption = captionRange.location == NSNotFound ? "" : nsString.substring(with: captionRange)

            guard let replacement = transform(source, caption) else { continue }

            output.replaceCharacters(in: fullRange, with: replacement)
        }

        return output as String
    }

    private static func isWebMURL(_ candidate: String) -> Bool {
        let stripped = candidate
            .split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
            .first ?? Substring(candidate)
        let withoutQuery = stripped
            .split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
            .first ?? stripped
        return withoutQuery.lowercased().hasSuffix(".webm")
    }

    private static func plainText(fromHTML html: String) -> String {
        let noTags = html.replacingOccurrences(
            of: #"<[^>]+>"#,
            with: "",
            options: .regularExpression
        )
        let decoded = noTags
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
        return decoded.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func inlineVideoHTML(source: String, caption: String) -> String {
        let escapedSource = escapeHTML(source)
        let cleanedCaption = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        let shouldRenderCaption = !cleanedCaption.isEmpty && cleanedCaption != source
        let captionHTML = shouldRenderCaption
            ? "<figcaption>\(escapeHTML(cleanedCaption))</figcaption>"
            : ""

        return """
        <figure class="embedded-video"><video controls preload="metadata" playsinline><source src="\(escapedSource)" type="video/webm">Your browser does not support WebM video playback.</video>\(captionHTML)</figure>
        """
    }

    private static func escapeHTML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
