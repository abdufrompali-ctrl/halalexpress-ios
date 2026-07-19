import SwiftUI

struct ItemDetailView: View {
    let item: CatalogItem
    @EnvironmentObject private var cart: CartStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedOption: String?
    @State private var selections: [String: Bool] = [:]   // modifier id -> on/off
    @State private var quantity = 1

    var body: some View {
        Form {
            Section {
                if !item.desc.isEmpty {
                    Text(item.desc).font(.subheadline).foregroundStyle(.secondary)
                }
                LabeledContent("Price", value: String(format: "$%.2f", item.price))
            }

            if let options = item.options {
                Section("Choice") {
                    Picker("Option", selection: $selectedOption) {
                        ForEach(options, id: \.self) { Text($0).tag(Optional($0)) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }

            modifierSection("Toppings", item.customize?.toppings)
            modifierSection("Sauces", item.customize?.sauces)
            modifierSection("Extras", item.customize?.extras)

            Section {
                Stepper("Quantity: \(quantity)", value: $quantity, in: 1...20)
            }

            Section {
                Button {
                    cart.add(item, option: selectedOption,
                             customizations: customizationSummary(), quantity: quantity)
                    dismiss()
                } label: {
                    Text("Add to Cart — \(dollars(Int((item.price * 100).rounded()) * quantity))")
                        .frame(maxWidth: .infinity)
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .disabled(item.options != nil && selectedOption == nil)
            }
            .listRowBackground(Color.clear)
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if selections.isEmpty, let c = item.customize {
                for mod in (c.toppings ?? []) + (c.sauces ?? []) + (c.extras ?? []) {
                    selections[mod.id] = mod.isChecked
                }
            }
            if selectedOption == nil { selectedOption = item.options?.first }
        }
    }

    @ViewBuilder
    private func modifierSection(_ title: String, _ mods: [Modifier]?) -> some View {
        if let mods, !mods.isEmpty {
            Section(title) {
                ForEach(mods) { mod in
                    Toggle(mod.label, isOn: Binding(
                        get: { selections[mod.id] ?? mod.isChecked },
                        set: { selections[mod.id] = $0 }
                    ))
                }
            }
        }
    }

    /// Diff selections against defaults into the note the kitchen ticket shows,
    /// matching the website's convention: "No Lettuce, Add Corn".
    private func customizationSummary() -> String? {
        guard let c = item.customize else { return nil }
        var parts: [String] = []
        for mod in (c.toppings ?? []) + (c.sauces ?? []) + (c.extras ?? []) {
            let on = selections[mod.id] ?? mod.isChecked
            if mod.isChecked && !on { parts.append("No \(mod.label)") }
            if !mod.isChecked && on { parts.append("Add \(mod.label)") }
        }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
}
