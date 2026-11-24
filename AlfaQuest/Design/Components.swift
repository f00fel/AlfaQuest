import SwiftUI

struct Page<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                content
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }
}

struct Surface<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 24))
    }
}

struct ScreenHeading: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(.largeTitle, design: .default, weight: .bold))
                .tracking(-0.8)
                .fixedSize(horizontal: false, vertical: true)
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(AppColors.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct PrimaryButton: View {
    let title: String
    var symbol: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                if let symbol { Image(systemName: symbol) }
            }
            .font(.system(.body, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(AppColors.accent, in: RoundedRectangle(cornerRadius: 17))
        }
        .buttonStyle(PressButtonStyle())
    }
}

struct PressButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(isEnabled ? 1 : 0.4)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct IconButton: View {
    let symbol: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 48, height: 48)
                .background(AppColors.surface.opacity(0.9), in: Circle())
        }
        .buttonStyle(PressButtonStyle())
        .accessibilityLabel(label)
    }
}

struct DetailPage<Content: View>: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                IconButton(symbol: "xmark", label: "Закрыть") { dismiss() }
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)
            Page { content }
        }
        .foregroundColor(AppColors.text)
        .background(AppColors.background.ignoresSafeArea())
    }
}

struct ProfileFields: View {
    @Binding var name: String
    @Binding var department: String

    static func isValid(name: String, department: String) -> Bool {
        [name, department].allSatisfy {
            let value = $0.trimmingCharacters(in: .whitespacesAndNewlines)
            return !value.isEmpty && value.count <= 60
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            input("Имя в игре", placeholder: "Как тебя называть", text: $name)
            input("Отдел", placeholder: "Название отдела", text: $department)
        }
    }

    private func input(_ title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption).foregroundColor(AppColors.secondary)
            TextField(placeholder, text: text)
                .textInputAutocapitalization(.words)
                .textFieldStyle(.plain)
                .padding(16)
                .background(AppColors.raised, in: RoundedRectangle(cornerRadius: 15))
                .accessibilityLabel(title)
        }
    }
}
