import SwiftUI

struct CommentPopoverView: View {
    let quote: String
    var existingComment: String? = nil
    var onSave: ((String) -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    let onDismiss: () -> Void

    @State private var comment = ""
    @FocusState private var isFocused: Bool

    private var isNewMode: Bool { existingComment == nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(quote)
                .font(.callout)
                .foregroundColor(.secondary)
                .lineLimit(3)
                .truncationMode(.tail)

            if isNewMode {
                TextEditor(text: $comment)
                    .font(.body)
                    .frame(minHeight: 60, maxHeight: 100)
                    .focused($isFocused)

                HStack {
                    Button("Cancel") { onDismiss() }
                        .keyboardShortcut(.escape, modifiers: [])
                    Spacer()
                    Button("Save") { onSave?(comment) }
                        .keyboardShortcut(.return, modifiers: .command)
                        .disabled(comment.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } else {
                ScrollView {
                    Text(existingComment ?? "")
                        .font(.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 100)

                HStack {
                    Button("Close") { onDismiss() }
                        .keyboardShortcut(.escape, modifiers: [])
                    Spacer()
                    Button("Delete", role: .destructive) { onDelete?() }
                }
            }
        }
        .padding(12)
        .frame(width: 300)
        .onAppear {
            if isNewMode { isFocused = true }
        }
    }
}
