import Foundation

func processTaskListCheckboxHTML(_ html: String) -> String {
    var result = html
    result = result.replacingOccurrences(
        of: "<li>[ ] ",
        with: "<li class=\"task\"><input type=\"checkbox\"> "
    )
    result = result.replacingOccurrences(
        of: "<li>[x] ",
        with: "<li class=\"task\"><input type=\"checkbox\" checked> ",
        options: .caseInsensitive
    )
    return result
}
