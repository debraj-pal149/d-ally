import SwiftData
import SwiftUI

struct BookmarkEditorView: View {
    var bookmarkId: UUID?
    var day: Date

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var scheme
    @Query private var bookmarks: [DayBookmark]

    @State private var title = ""
    @State private var notes = ""
    @State private var confirmDelete = false
    @State private var didLoad = false

    private var existing: DayBookmark? {
        guard let bookmarkId else { return nil }
        return bookmarks.first { $0.id == bookmarkId }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isCreate: Bool { existing == nil }

    private var navTitle: String {
        isCreate ? "New day bookmark" : "Edit day bookmark"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isCreate {
                    Text(AppCopy.bookmarkIntro)
                        .font(AppTypography.footnote)
                        .foregroundStyle(AppColors.textSecondary(scheme))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                        .background(Color(.systemGroupedBackground))
                }

                Form {
                    Section {
                        LabeledContent("Day", value: TimeDisplay.weekdayMonthDay(day))
                    }

                    Section {
                        TextField("Title", text: $title)
                    }

                    Section {
                        NotesEditorField(notes: $notes)
                    }

                    if existing != nil {
                        Section {
                            Button("Delete bookmark", role: .destructive) { confirmDelete = true }
                        }
                    }
                }
                .contentMargins(.top, isCreate ? 12 : nil, for: .scrollContent)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(!canSave)
                }
            }
            .onAppear(perform: loadIfNeeded)
            .alert("Delete this bookmark?", isPresented: $confirmDelete) {
                Button("Delete", role: .destructive, action: deleteBookmark)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Removes it from this day only.")
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color(.systemGroupedBackground))
    }

    private func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        if let existing {
            title = existing.title
            notes = existing.notes
        }
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let now = Date()
        if let existing {
            existing.title = trimmed
            existing.notes = notes
            existing.updatedAt = now
            existing.deletedAt = nil
            try? modelContext.save()
            SyncRecorder.bookmarkChanged(existing.id, at: now, in: modelContext)
        } else {
            let bookmark = DayBookmark(
                title: trimmed,
                notes: notes,
                dayKey: day.localDayKey,
                createdAt: now,
                updatedAt: now
            )
            modelContext.insert(bookmark)
            try? modelContext.save()
            SyncRecorder.bookmarkChanged(bookmark.id, at: now, in: modelContext)
        }
        DayLogService.refreshAfterChange(context: modelContext)
        dismiss()
    }

    private func deleteBookmark() {
        guard let existing else { return }
        let now = Date()
        existing.deletedAt = now
        existing.updatedAt = now
        try? modelContext.save()
        SyncRecorder.bookmarkChanged(existing.id, at: now, in: modelContext)
        DayLogService.refreshAfterChange(context: modelContext)
        dismiss()
    }
}
