import SwiftUI

struct TagChipButton: View {
    let title: String
    var count: Int?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if showsTagIcon {
                    Image(systemName: "tag.fill")
                        .font(.caption2)
                }
                Text(title)
                    .font(.caption.weight(.semibold))
                if let count {
                    Text("\(count)")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(isSelected ? 0.2 : 0.08), in: Capsule())
                }
            }
            .foregroundStyle(isSelected ? CertWatchTheme.healthy : CertWatchTheme.secondaryText)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? CertWatchTheme.healthy.opacity(0.18) : Color.white.opacity(0.06))
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? CertWatchTheme.healthy.opacity(0.45) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var showsTagIcon: Bool {
        title != "All" && title != "None"
    }
}

struct TagChipLabel: View {
    let title: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "tag.fill")
                .font(.caption2)
            Text(title)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(CertWatchTheme.healthy)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(CertWatchTheme.healthy.opacity(0.14), in: Capsule())
    }
}

struct TagFilterBar: View {
    @Binding var selectedTag: String?
    let tags: [(name: String, count: Int)]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                TagChipButton(title: "All", isSelected: selectedTag == nil) {
                    selectedTag = nil
                }
                ForEach(tags, id: \.name) { item in
                    TagChipButton(
                        title: item.name,
                        count: item.count,
                        isSelected: selectedTag == item.name
                    ) {
                        selectedTag = item.name
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }
}

struct TagPickerField: View {
    @Binding var selection: String
    let suggestions: [String]
    var onDeleteTag: ((String) -> Void)?

    @State private var customInput = ""
    @State private var tagPendingDeletion: String?
    @FocusState private var customFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !selection.isEmpty {
                HStack(spacing: 8) {
                    Text("Selected")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(CertWatchTheme.tertiaryText)
                    TagChipLabel(title: selection)
                    Spacer()
                    Button("Clear") {
                        selection = ""
                        customInput = ""
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(CertWatchTheme.secondaryText)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Choose a tag")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(CertWatchTheme.tertiaryText)

                FlowLayout(spacing: 8) {
                    TagChipButton(title: "None", isSelected: selection.isEmpty) {
                        selection = ""
                        customInput = ""
                    }
                    ForEach(displayedSuggestions, id: \.self) { tag in
                        TagChipButton(title: tag, isSelected: selection == tag) {
                            selection = tag
                            customInput = ""
                        }
                        .contextMenu {
                            Button("Delete Tag", systemImage: "trash", role: .destructive) {
                                tagPendingDeletion = tag
                            }
                        }
                    }
                }

                if onDeleteTag != nil {
                    Text("Long-press a tag to delete it from all domains.")
                        .font(.caption2)
                        .foregroundStyle(CertWatchTheme.tertiaryText)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Or create one")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(CertWatchTheme.tertiaryText)

                HStack(spacing: 10) {
                    TextField("Custom tag name", text: $customInput)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .focused($customFieldFocused)
                        .submitLabel(.done)
                        .onSubmit(applyCustomTag)

                    Button("Use") {
                        applyCustomTag()
                    }
                    .font(.caption.weight(.semibold))
                    .disabled(EndpointTags.normalize(customInput) == nil)
                }
                .padding(12)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .confirmationDialog(
            "Delete tag?",
            isPresented: Binding(
                get: { tagPendingDeletion != nil },
                set: { if !$0 { tagPendingDeletion = nil } }
            ),
            titleVisibility: .visible,
            presenting: tagPendingDeletion
        ) { tag in
            Button("Delete “\(tag)”", role: .destructive) {
                if selection == tag {
                    selection = ""
                }
                onDeleteTag?(tag)
                tagPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                tagPendingDeletion = nil
            }
        } message: { tag in
            Text("Removes this tag from every domain and hides it from your tag list.")
        }
    }

    private var displayedSuggestions: [String] {
        EndpointTags.displayOptions(base: suggestions, including: selection)
    }

    private func applyCustomTag() {
        guard let normalized = EndpointTags.normalize(customInput) else { return }
        EndpointTags.remember(normalized)
        selection = normalized
        customInput = ""
        customFieldFocused = false
    }
}
