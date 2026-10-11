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
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var draft: TransactionDraft
    @State private var showCamera: Bool = false
    @State private var text: String?
    @State private var isParsing: Bool = false
    @State private var scannedMerchant: String?
    
    @Query var categories: [Category]
    @Query var sources: [Source]
    
    init(transaction: Transaction? = nil, selectedKind: TransactionKind = .expense, sharedReceiptText: String? = nil) {
        self.transaction = transaction
        self.sharedReceiptText = sharedReceiptText
        var draft: TransactionDraft
        if let transaction {
            draft = TransactionDraft(transaction)
        } else {
            draft = TransactionDraft()
            draft.kind = selectedKind
        }
        _draft = State(initialValue: draft)
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
        learnMerchantCategory()
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
        learnMerchantCategory()
        if let kaChingSoundID {
            AudioServicesPlaySystemSound(kaChingSoundID)
        }
        dismiss()
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
            defer { isParsing = false }

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
        }
    }
    
    private func onScan() {
        ReceiptParser.prewarm()
        showCamera = true
    }
    
    var body: some View {
        if isParsing {
            Text("parsing")
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
        }
        .fullScreenCover(isPresented: $showCamera) {
            ReceiptScannerView(
                onScanFinished: { isParsing = true },
                onTextRecognized: parseText,
                onDismiss: {
                    showCamera = false
                }
            )
            .ignoresSafeArea()
        }
        .onAppear(perform: suggestSources)
        .onChange(of: sharedReceiptText, initial: true) {
            if let sharedReceiptText { parseText(sharedReceiptText) }
        }
        .onChange(of: draft.kind, onKindChange)
        .navigationTitle(isEditing ? "edit_transaction" : "add_transaction")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(action: isEditing ? editTransaction : addTransaction) {
                    Image(systemName: "arrow.down.circle")
                }
                .disabled(!isValid)
            }
        }
    }
}

#Preview {
    AddTransactionView(selectedKind: .income).modelContainer(makeMainViewPreviewContainer())
}
