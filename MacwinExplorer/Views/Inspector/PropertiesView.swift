import SwiftUI
import AppKit

struct PropertiesRequest: Identifiable {
    let id = UUID()
    let items: [FileSystemItem]
}

struct PropertiesView: View {
    let items: [FileSystemItem]
    @Environment(\.dismiss) private var dismiss
    @State private var calculatedSize: Int64?

    private var singleItem: FileSystemItem? { items.count == 1 ? items.first : nil }

    var body: some View {
        VStack(spacing: 14) {
            if let item = singleItem {
                Image(nsImage: item.icon)
                    .resizable()
                    .frame(width: 64, height: 64)
                Text(item.name)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            } else {
                Image(systemName: "square.stack.3d.up")
                    .font(.system(size: 44))
                    .foregroundStyle(.secondary)
                Text("Выбрано объектов: \(items.count)")
                    .font(.headline)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                if let item = singleItem {
                    LabeledContent("Тип", value: item.kindDescription)
                    LabeledContent("Расположение", value: item.url.deletingLastPathComponent().path)
                }
                LabeledContent("Размер") {
                    if let calculatedSize {
                        Text(FileSizeFormatter.string(from: calculatedSize))
                    } else {
                        ProgressView().controlSize(.small)
                    }
                }
                if let item = singleItem {
                    if let created = item.creationDate {
                        LabeledContent("Создан", value: DateFormatter.explorerStyle.string(from: created))
                    }
                    if let modified = item.modificationDate {
                        LabeledContent("Изменён", value: DateFormatter.explorerStyle.string(from: modified))
                    }
                }
            }
            .font(.callout)
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            HStack {
                Spacer()
                Button("Готово") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 320, height: 340)
        .task {
            let urls = items.map(\.url)
            calculatedSize = await Task.detached(priority: .userInitiated) {
                urls.reduce(Int64(0)) { $0 + DirectorySizeCalculator.size(of: $1) }
            }.value
        }
    }
}
