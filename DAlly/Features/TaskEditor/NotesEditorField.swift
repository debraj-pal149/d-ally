import SwiftUI

struct NotesEditorField: View {
    @Binding var notes: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Notes")
            TextField("Optional notes", text: $notes, axis: .vertical)
                .lineLimit(3...8)
                .onChange(of: notes) { _, new in
                    if new.count > AppDefaults.notesMaxLength {
                        notes = String(new.prefix(AppDefaults.notesMaxLength))
                    }
                }
        }
    }
}
