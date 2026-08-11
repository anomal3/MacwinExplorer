import SwiftUI

struct StatusBarView: View {
    let fileList: FileListViewModel
    let currentDirectory: URL

    private var itemCountText: String {
        let count = fileList.items.count
        return "\(count) объект" + pluralSuffix(for: count)
    }

    private func pluralSuffix(for count: Int) -> String {
        let mod10 = count % 10
        let mod100 = count % 100
        if mod10 == 1 && mod100 != 11 { return "" }
        if (2...4).contains(mod10) && !(12...14).contains(mod100) { return "а" }
        return "ов"
    }

    private var freeSpaceText: String? {
        FileSystemService.availableCapacity(for: currentDirectory).map { "Свободно: \(FileSizeFormatter.string(from: $0))" }
    }

    var body: some View {
        HStack {
            Text(itemCountText)
            if let selectedSize = fileList.selectedSizeDescription {
                Text("• Выбрано: \(fileList.selection.count) (\(selectedSize))")
            }
            Spacer()
            if let freeSpaceText {
                Text(freeSpaceText)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}
