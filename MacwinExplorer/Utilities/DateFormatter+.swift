import Foundation

extension DateFormatter {
    static let explorerStyle: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
}
