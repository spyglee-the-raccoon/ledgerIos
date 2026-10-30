//
//  ReceiptViews.swift
//  Ledger
//
//  Created by Maksym Bahrov on 28.10.2026..
//

import SwiftUI

/// A horizontal strip of receipt page thumbnails that opens a full-screen viewer.
struct ReceiptPhotosView: View {
    let pages: [Data]

    @State private var selectedPage: PageSelection?

    var body: some View {
        ScrollView(.horizontal) {
            HStack {
                ForEach(pages.indices, id: \.self) { index in
                    if let image = UIImage(data: pages[index]) {
                        Button {
                            selectedPage = PageSelection(id: index)
                        } label: {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 110)
                                .clipShape(.rect(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("receipt_page \(index + 1)"))
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
        .fullScreenCover(item: $selectedPage) { page in
            ReceiptPhotoViewer(pages: pages, initialPage: page.id)
        }
    }
}

private struct PageSelection: Identifiable {
    let id: Int
}

/// Full-screen, pageable receipt viewer with pinch to zoom.
private struct ReceiptPhotoViewer: View {
    let pages: [Data]
    @State var selection: Int

    @Environment(\.dismiss) private var dismiss

    init(pages: [Data], initialPage: Int) {
        self.pages = pages
        _selection = State(initialValue: initialPage)
    }

    var body: some View {
        NavigationStack {
            TabView(selection: $selection) {
                ForEach(pages.indices, id: \.self) { index in
                    ZoomableImage(data: pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: pages.count > 1 ? .automatic : .never))
            .background(.black)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
            }
        }
    }
}

private struct ZoomableImage: View {
    let data: Data

    @State private var scale: CGFloat = 1
    @State private var baseScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var baseOffset: CGSize = .zero

    var body: some View {
        if let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    MagnifyGesture()
                        .onChanged { scale = max(1, baseScale * $0.magnification) }
                        .onEnded { _ in baseScale = scale }
                        .simultaneously(with: DragGesture()
                            .onChanged { value in
                                guard scale > 1 else { return }
                                offset = CGSize(
                                    width: baseOffset.width + value.translation.width,
                                    height: baseOffset.height + value.translation.height
                                )
                            }
                            .onEnded { _ in baseOffset = offset }
                        )
                )
                .onTapGesture(count: 2) {
                    withAnimation(.snappy) {
                        let zoomedIn = scale > 1
                        scale = zoomedIn ? 1 : 2.5
                        baseScale = scale
                        offset = .zero
                        baseOffset = .zero
                    }
                }
        }
    }
}

/// One recognized product line: name, quantity × unit price and the line total.
struct ReceiptItemRowView: View {
    let name: String
    let quantity: Decimal
    let unitPrice: Decimal
    let totalPrice: Decimal

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(name)
                if quantity != 1 {
                    Text(verbatim: "\(quantity.formatted()) × \(unitPrice.formatted(.currency(code: currency)))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(totalPrice, format: .currency(code: currency))
        }
    }
}

/// Adds a product line or fixes one that was recognized incorrectly.
struct ReceiptItemEditorView: View {
    let isNew: Bool
    let onSave: (ParsedReceiptItem) -> Void

    @State private var item: ParsedReceiptItem
    @Environment(\.dismiss) private var dismiss

    init(item: ParsedReceiptItem, isNew: Bool, onSave: @escaping (ParsedReceiptItem) -> Void) {
        self.isNew = isNew
        self.onSave = onSave
        _item = State(initialValue: item)
    }

    private var isValid: Bool {
        !item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && item.quantity > 0 && item.totalPrice >= 0
    }

    /// Keeps the line total in step with quantity × unit price; the total can still
    /// be changed afterwards, e.g. for a discounted line.
    private func updateTotal() {
        var total = item.quantity * item.unitPrice
        var rounded = Decimal()
        NSDecimalRound(&rounded, &total, 2, .plain)
        item.totalPrice = rounded
    }

    private func save() {
        item.name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
        onSave(item)
        dismiss()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("name") {
                    TextField("name", text: $item.name)
                }
                Section {
                    LabeledContent("quantity") {
                        TextField("quantity", value: $item.quantity, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("unit_price") {
                        TextField("unit_price", value: $item.unitPrice, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("total_price") {
                        TextField("total_price", value: $item.totalPrice, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .onChange(of: item.quantity) { updateTotal() }
            .onChange(of: item.unitPrice) { updateTotal() }
            .navigationTitle(isNew ? "add_item" : "edit_item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: save) {
                        Image(systemName: "arrow.down.circle")
                    }
                    .disabled(!isValid)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    List {
        ReceiptItemRowView(name: "MLIJEKO 2,8% 1L", quantity: 2, unitPrice: 1.29, totalPrice: 2.58)
        ReceiptItemRowView(name: "KRUH POLUBIJELI", quantity: 1, unitPrice: 1.49, totalPrice: 1.49)
    }
}
