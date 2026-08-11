import SwiftUI
import AppKit

/// Windows-Explorer-style "how full is this drive" preview: shown when the
/// selection (or the current folder itself) is the root of a mounted volume —
/// the internal system disk or a removable one like a USB flash drive.
struct VolumeUsagePreviewView: View {
    let url: URL

    private var usage: FileSystemService.VolumeUsage? { FileSystemService.volumeUsage(for: url) }

    var body: some View {
        VStack(spacing: 18) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .frame(width: 64, height: 64)

            Text(usage?.name ?? url.lastPathComponent)
                .font(.title3.bold())
                .multilineTextAlignment(.center)

            if let usage {
                DiskUsageRing(used: usage.usedCapacity, total: usage.totalCapacity)
                    .frame(width: 140, height: 140)

                VStack(alignment: .leading, spacing: 8) {
                    LabeledContent("Занято", value: FileSizeFormatter.string(from: usage.usedCapacity))
                    LabeledContent("Свободно", value: FileSizeFormatter.string(from: usage.availableCapacity))
                    LabeledContent("Всего", value: FileSizeFormatter.string(from: usage.totalCapacity))
                }
                .font(.callout)
                .padding(.horizontal, 24)
            } else {
                Text("Нет данных о диске")
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.top, 30)
        .frame(maxWidth: .infinity)
    }
}

private struct DiskUsageRing: View {
    let used: Int64
    let total: Int64

    private var fraction: Double {
        guard total > 0 else { return 0 }
        return min(1, max(0, Double(used) / Double(total)))
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 14)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(
                    AngularGradient(colors: [.blue, .cyan], center: .center),
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Text("\(Int(fraction * 100))%")
                    .font(.title2.bold())
                Text("занято")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
