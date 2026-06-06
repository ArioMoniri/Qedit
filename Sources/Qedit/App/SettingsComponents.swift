import SwiftUI

/// The one status glyph used on every toggle row — a clear ✓ On / ✗ Off chip (state shown by
/// glyph + text, never color alone).
struct StatusCapsule: View {
    let isOn: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isOn ? "checkmark.circle.fill" : "xmark.circle")
            Text(isOn ? "On" : "Off")
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(isOn ? Color.green : Color.secondary)
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(Capsule().fill(isOn ? Color.green.opacity(0.16) : Color.secondary.opacity(0.12)))
        .animation(reduceMotion ? nil : .snappy(duration: 0.18), value: isOn)
        .accessibilityLabel(isOn ? "On" : "Off")
    }
}

/// The universal toggle row: the whole card is the hit target; the trailing capsule shows state.
struct SettingRow: View {
    let icon: String
    var tint: Color = .accentColor
    let title: String
    let detail: String
    @Binding var isOn: Bool
    var enabled: Bool = true

    var body: some View {
        Button { if enabled { isOn.toggle() } } label: {
            HStack(spacing: 11) {
                Image(systemName: icon)
                    .frame(width: 22)
                    .foregroundStyle(isOn ? tint : Color.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).fontWeight(.medium)
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 12)
                StatusCapsule(isOn: isOn)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10)
                .fill(isOn ? tint.opacity(0.07) : Color(nsColor: .controlBackgroundColor)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityHint(detail)
        .accessibilityAddTraits(.isButton)
    }
}

/// Section header with a title and a live "N / M on" count chip (the primary at-a-glance status).
struct SettingsSectionHeader: View {
    let title: String
    var subtitle: String?
    var onCount: Int?
    var total: Int?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                if let subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let onCount, let total {
                Text("\(onCount) / \(total) on")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(Color.secondary.opacity(0.12)))
            }
        }
    }
}

/// A grouped card used to partition a settings tab.
struct SettingsGroup<Content: View>: View {
    let title: String
    var subtitle: String?
    var onCount: Int?
    var total: Int?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingsSectionHeader(title: title, subtitle: subtitle, onCount: onCount, total: total)
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 14))
    }
}
