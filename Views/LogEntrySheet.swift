import SwiftUI

struct LogEntrySheet: View {
    @ObservedObject var store: ActivityStore
    let draft: DraftLogEntry

    @Environment(\.dismiss) private var dismiss
    @State private var note: String
    @State private var rating: Int
    @State private var timestamp: Date

    init(store: ActivityStore, draft: DraftLogEntry) {
        self.store = store
        self.draft = draft
        _note = State(initialValue: draft.note)
        _rating = State(initialValue: draft.rating)
        _timestamp = State(initialValue: draft.timestamp)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(draft.prompt)
                        .foregroundStyle(FloTimeTheme.text)
                }

                Section("What were you up to?") {
                    TextField("Worked on a paper, studied, cleaned, met with a team...", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Productivity Rating") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Rating")
                            Spacer()
                            RatingBadge(rating: rating)
                        }

                        Slider(value: Binding(
                            get: { Double(rating) },
                            set: { rating = Int($0.rounded()) }
                        ), in: 1...10, step: 1)
                        .tint(FloTimeTheme.primary)
                    }
                }

                Section("When?") {
                    DatePicker("Timestamp", selection: $timestamp)
                }
            }
            .scrollContentBackground(.hidden)
            .background(FloTimeTheme.background)
            .navigationTitle(draft.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        store.dismissDraft()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.saveDraft(
                            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                            rating: rating,
                            timestamp: timestamp,
                            source: draft.source,
                            calendarEventID: draft.calendarEventID,
                            existingLogID: draft.existingLogID
                        )
                        dismiss()
                    }
                    .disabled(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if let existingLogID = draft.existingLogID {
                    ToolbarItem(placement: .bottomBar) {
                        Button("Delete Activity", role: .destructive) {
                            store.deleteLog(id: existingLogID)
                            store.dismissDraft()
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}
