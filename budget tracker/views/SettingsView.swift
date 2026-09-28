//
//  SettingsView.swift
//  budget tracker
//
//  Created by Maksym Bahrov on 14.09.2026..
//

import SwiftUI
import SwiftData

private enum ActiveSheet: Identifiable {
    case categories, sources
    var id: Self { self }
}


struct SettingsView: View {
    @State private var activeSheet: ActiveSheet?
    
    func openCategories () {
        activeSheet = .categories
    }
    
    func openSources () {
        activeSheet = .sources
    }
    
    var body: some View {
        VStack {
            Section {
                Button("Categories", action: openCategories)
                Button("Sources", action: openSources)
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .categories: CategoriesView()
            case .sources: SourcesView()
            }
            
        }
    }
}

#Preview {
    SettingsView().modelContainer(makeMainViewPreviewContainer())
}
