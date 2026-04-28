import SwiftUI

struct CommentPopoverView: View {
    let quote: String
    let onSave: (String) -> Void
    let onCancel: () -> Void

    @State private var comment = ""
    @FocusState private var isFocused: Bool

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
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.escape, modifiers: [])
                Spacer()
                Button("Save") { onSave(comment) }
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(comment.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(12)
        .frame(width: 300)
        .onAppear { isFocused = true }
    }
}
