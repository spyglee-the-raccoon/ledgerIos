//
//  SourcesView.swift
//  ledger
//
//  Created by Maksym Bahrov on 18.09.2026..
//

import SwiftUI
import SwiftData

private enum SourceSheet: Identifiable {
    case add
    case edit(Source)

    var id: PersistentIdentifier? {
        switch self {
        case .add: nil
        case .edit(let source): source.persistentModelID
        }
    }
}

struct SourcesView: View {
    @Environment(\.modelContext) var modelContext
    @Query var sources: [Source]
    @State private var presentedSheet: SourceSheet?
    
    func addSource(_ draft: SourceDraft) {
        let newSource = Source()
        draft.apply(to: newSource)
        modelContext.insert(newSource)
    }
    
    func updateSource(_ source: Source, with draft: SourceDraft) {
        draft.apply(to: source)
    }
    
    func deleteSource(_ indexSet: IndexSet) {
        for index in indexSet {
            let source = sources[index]
            modelContext.delete(source)
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(sources) { source in
                    Button {
                        presentedSheet = .edit(source)
                    } label: {
                        HStack {
                            Image(systemName: source.systemImage)
                                .foregroundStyle(source.color.color)
                            Text(source.name)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
                .onDelete(perform: deleteSource)
            }
            .navigationTitle("sources")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("add_source", systemImage: "plus") {
                    presentedSheet = .add
                }
            }
            .sheet(item: $presentedSheet) { sheet in
                switch sheet {
                case .add:
                    AddSourceView { draft in
                        addSource(draft)
                    }
                case .edit(let source):
                    AddSourceView(source: source) { draft in
                        updateSource(source, with: draft)
                    }
                }
            }
        }
    }
}

#Preview {
    SourcesView().modelContainer(makeMainViewPreviewContainer())
}
