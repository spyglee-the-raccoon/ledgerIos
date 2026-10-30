//
//  AddTransactionView.swift
//  ledger
//
//  Created by Maksym Bahrov on 14.09.2026..
//

import SwiftUI
import SwiftData
import AudioToolbox
import VisionKit

private let kaChingSoundID: SystemSoundID? = {
    let url = URL(fileURLWithPath: "/System/Library/Audio/UISounds/payment_success.caf")
    var soundID: SystemSoundID = 0
    let status = AudioServicesCreateSystemSoundID(url as CFURL, &soundID)
    return status == kAudioServicesNoError ? soundID : nil
}()

struct AddTransactionView: View {
    var transaction: Transaction?
    var sharedReceiptText: String?
    /// Opens the receipt scanner right away, for the Scan quick action.
    var startsScanning = false

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var draft: TransactionDraft
    @State private var showCamera: Bool = false
    @State private var text: String?
    @State private var isParsing: Bool = false
    @State private var scannedMerchant: String?
    @State private var scannedPhotos: [Data] = []
    /// Receipt items being edited; saved items are only replaced when this changes.
    @State private var items: [ParsedReceiptItem]
    @State private var itemsChanged: Bool = false
    @State private var editingItem: ParsedReceiptItem?
    @State private var isRecognizingItems: Bool = false
    
    @Query var categories: [Category]
    @Query var sources: [Source]
    
    init(transaction: Transaction? = nil, selectedKind: TransactionKind = .expense, sharedReceiptText: String? = nil, startsScanning: Bool = false) {
        self.transaction = transaction
        self.sharedReceiptText = sharedReceiptText
        self.startsScanning = startsScanning
        var draft: TransactionDraft
        if let transaction {
            draft = TransactionDraft(transaction)
        } else {
            draft = TransactionDraft()
            draft.kind = selectedKind
        }
        _draft = State(initialValue: draft)
        let savedItems = (transaction?.receiptItems ?? []).sorted { $0.position < $1.position }
        _items = State(initialValue: savedItems.map {
            ParsedReceiptItem(name: $0.name, quantity: $0.quantity, unitPrice: $0.unitPrice, totalPrice: $0.totalPrice)
        })
    }
    
    var isEditing: Bool {
        transaction != nil
    }
    
    private var incomeCategories: [Category] {
        categories.filter { $0.categoryKind == .income }
    }
    
    private var expenseCategories: [Category] {
        categories.filter { $0.categoryKind == .expense }
    }
    
    private var availableCategories: [Category] {
        self.draft.kind == .income ? incomeCategories : expenseCategories
    }
    
    private func editTransaction() {
        guard let transaction else { return }
        draft.apply(to: transaction)
        if itemsChanged, draft.kind == .expense {
            (transaction.receiptItems ?? []).forEach(modelContext.delete)
            transaction.receiptItems = makeReceiptItems()
        }
        learnMerchantCategory()
        BudgetNotifier.check(in: modelContext)
        dismiss()
    }
    
    private func learnMerchantCategory() {
        guard let scannedMerchant, draft.kind == .expense, let category = draft.category else { return }
        MerchantCategory.learn(merchant: scannedMerchant, category: category, source: draft.source, in: modelContext)
    }
    
    private func suggestSources() {
        guard !isEditing else { return }
        if draft.kind != .income, draft.source == nil {
            draft.source = SourceSuggestion.mostLikely(.source, for: draft.kind, in: modelContext)
        }
        if draft.kind != .expense, draft.destination == nil {
            draft.destination = SourceSuggestion.mostLikely(
                .destination, for: draft.kind, excluding: draft.source, in: modelContext
            )
        }
    }
    
    private func onKindChange() {
        if draft.kind == .income { draft.source = nil }
        if draft.kind == .expense { draft.destination = nil }
        suggestSources()
    }
    
    private func addTransaction() {
        let newTransaction = Transaction(
            amount: draft.amount,
            kind: draft.kind,
            source: draft.source,
            destination: draft.destination,
            note: draft.note,
            date: draft.date,
            category: draft.category
        )
        modelContext.insert(newTransaction)
        attachReceipt(to: newTransaction)
        learnMerchantCategory()
        BudgetNotifier.check(in: modelContext)
        if let kaChingSoundID {
            AudioServicesPlaySystemSound(kaChingSoundID)
        }
        dismiss()
    }
    
    /// Saves the scanned pages and recognized items with the transaction.
    private func attachReceipt(to transaction: Transaction) {
        transaction.receiptPhotos = scannedPhotos.enumerated().map { index, data in
            ReceiptPhoto(imageData: data, pageIndex: index)
        }
        // Item prices only make sense for purchases.
        guard draft.kind == .expense else { return }
        transaction.receiptItems = makeReceiptItems()
    }

    private func makeReceiptItems() -> [ReceiptItem] {
        items.enumerated().map { index, item in
            ReceiptItem(
                name: item.name,
                quantity: item.quantity,
                unitPrice: item.unitPrice,
                totalPrice: item.totalPrice,
                position: index
            )
        }
    }

    private func saveItem(_ item: ParsedReceiptItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        } else {
            items.append(item)
        }
        itemsChanged = true
    }

    private var savedPhotos: [Data] {
        (transaction?.receiptPhotos ?? [])
            .sorted { $0.pageIndex < $1.pageIndex }
            .map(\.imageData)
    }

    private var isValid: Bool {
        switch draft.kind {
        case .expense:
            return draft.amount > 0 && draft.category != nil && draft.source != nil
        case .income:
            return draft.amount > 0 && draft.category != nil && draft.destination != nil
        case .transfer:
            return draft.amount > 0 && draft.source != nil && draft.destination != nil
        }
    }
    
    private func getTransactionKindName(_ kind: TransactionKind) -> LocalizedStringResource {
        switch(kind) {
        case .expense:
            return "expense"
        case .income:
            return "income"
        case .transfer:
            return "transfer"
        }
    }
    
    private func parseText(_ recognizedText: String) -> Void {
        guard !recognizedText.isEmpty else {
            isParsing = false
            return
        }
        Task { @MainActor in
            isParsing = true
            isRecognizingItems = true
            defer {
                isParsing = false
                isRecognizingItems = false
            }

            let receipt = await ReceiptParser.parse(
                recognizedText,
                categoryNames: expenseCategories.map(\.name)
            )
            draft.kind = .expense
            scannedMerchant = receipt.merchant

            let learned = receipt.merchant.flatMap { MerchantCategory.learned(for: $0, in: modelContext) }
            if let source = learned?.source {
                draft.source = source
            }
            if let category = learned?.category, category.categoryKind == .expense {
                draft.category = category
            } else if let categoryName = receipt.categoryName,
               let category = expenseCategories.first(where: { $0.name == categoryName }) {
                draft.category = category
            }
            if let total = receipt.total {
                draft.amount = total
            }
            if let merchant = receipt.merchant, draft.note.isEmpty {
                draft.note = merchant
            }
            if let date = receipt.date {
                draft.date = date
            }

            // The form is filled now; items keep loading in their own section.
            isParsing = false
            items = await ReceiptParser.parseItems(recognizedText)
            itemsChanged = true
        }
    }
    
    private func onScan() {
        ReceiptParser.prewarm()
        showCamera = true
    }
    
    var body: some View {
        if isParsing {
            ProgressView()
                .accessibilityLabel(Text("parsing"))
                .animation(.snappy)
        } else if !isEditing {
            
            Button(action: onScan) {
                HStack{
                    Image(systemName: "camera")
                    Text("scan_your_receipt")
                }
            }
            
            .disabled(!VNDocumentCameraViewController.isSupported)
        }
        Form {
            Section {
                DatePicker("date", selection: $draft.date, displayedComponents: [.date, .hourAndMinute])
                    .padding(.horizontal)
            }
            Picker("kind", selection: $draft.kind) {
                ForEach(TransactionKind.allCases) { kind in
                    Text(getTransactionKindName(kind))
                        .tag(kind)
                }
            }
            .pickerStyle(.segmented)
            
            
            Section("amount") {
                TextField("amount", value: $draft.amount, format: .number)
                    .keyboardType(.decimalPad)
            }
            
            if draft.kind != .income {
                Section {
                    Picker("source", selection: $draft.source) {
                        ForEach(sources) { source in
                            HStack {
                                Image(systemName: source.systemImage)
                                Text(source.name)
                            }
                            .tag(source)
                        }
                    }
                    .pickerStyle(.automatic)
                }
            }
            
            if draft.kind != .expense {
                Section {
                    Picker("destination", selection: $draft.destination) {
                        ForEach(sources) { source in
                            HStack {
                                Image(systemName: source.systemImage)
                                Text(source.name)
                            }
                            .tag(source)
                        }
                    }
                    .pickerStyle(.automatic)
                }
            }
            
            if draft.kind != .transfer {
                Section {
                    Picker("category", selection: $draft.category) {
                        ForEach(availableCategories) { category in
                            HStack {
                                Image(systemName: category.systemImage)
                                Text(category.name)
                            }
                            .tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            Section("note") {
                TextField("note", text: $draft.note)
            }

            receiptSections
        }
        .fullScreenCover(isPresented: $showCamera) {
            ReceiptScannerView(
                onScanFinished: { isParsing = true },
                onPagesScanned: { scannedPhotos = $0 },
                onTextRecognized: parseText,
                onDismiss: {
                    showCamera = false
                }
            )
            .ignoresSafeArea()
        }
        .sheet(item: $editingItem) { item in
            ReceiptItemEditorView(
                item: item,
                isNew: !items.contains { $0.id == item.id },
                onSave: saveItem
            )
        }
        .onAppear(perform: suggestSources)
        .onChange(of: sharedReceiptText, initial: true) {
            if let sharedReceiptText { parseText(sharedReceiptText) }
        }
        .onChange(of: startsScanning, initial: true) {
            if startsScanning && !isEditing && VNDocumentCameraViewController.isSupported { onScan() }
        }
        .onChange(of: draft.kind, onKindChange)
        .navigationTitle(isEditing ? "edit_transaction" : "add_transaction")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(action: isEditing ? editTransaction : addTransaction) {
                    Image(systemName: "arrow.down.circle")
                }
                // Saving mid-recognition would drop the items that are still loading.
                .disabled(!isValid || isRecognizingItems)
            }
        }
    }

    @ViewBuilder
    private var receiptSections: some View {
        let photos = isEditing ? savedPhotos : scannedPhotos
        if !photos.isEmpty {
            Section("receipt") {
                ReceiptPhotosView(pages: photos)
            }
        }

        if draft.kind == .expense {
            Section {
                if isRecognizingItems {
                    HStack {
                        ProgressView()
                        Text("recognizing_items")
                            .foregroundStyle(.secondary)
                    }
                }
                ForEach(items) { item in
                    Button {
                        editingItem = item
                    } label: {
                        ReceiptItemRowView(name: item.name, quantity: item.quantity, unitPrice: item.unitPrice, totalPrice: item.totalPrice)
                    }
                    .tint(.primary)
                }
                .onDelete { offsets in
                    items.remove(atOffsets: offsets)
                    itemsChanged = true
                }
                if !isRecognizingItems {
                    Button("add_item", systemImage: "plus") {
                        editingItem = ParsedReceiptItem(name: "", quantity: 1, unitPrice: 0, totalPrice: 0)
                    }
                }
            } header: {
                Text("receipt_items")
            } footer: {
                if !items.isEmpty {
                    Text("receipt_items_footer")
                }
            }
        }
    }
}

#Preview {
    AddTransactionView(selectedKind: .income).modelContainer(makeMainViewPreviewContainer())
}
