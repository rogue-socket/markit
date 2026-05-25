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
    private var currentComment: String { existingComment ?? "" }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(quote)
                .font(.callout)
                .foregroundColor(.secondary)
                .lineLimit(3)
                .truncationMode(.tail)

            TextEditor(text: $comment)
                .font(.body)
                .frame(minHeight: 60, maxHeight: 100)
                .focused($isFocused)

            HStack {
                Button(isNewMode ? "Cancel" : "Close") { onDismiss() }
                    .keyboardShortcut(.escape, modifiers: [])
                Spacer()
                if !isNewMode {
                    Button("Delete", role: .destructive) { onDelete?() }
                }
                Button("Save") { onSave?(comment) }
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(12)
        .frame(width: 300)
        .onAppear {
            comment = currentComment
            isFocused = true
        }
    }
}
