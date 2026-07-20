import SwiftUI

struct ItemDetailView: View {
    let item: CatalogItem
    @EnvironmentObject private var cart: CartStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedOption: String?
    @State private var selections: [String: Bool] = [:]   // modifier id -> on/off
    @State private var quantity = 1

    private var totalCents: Int { Int((item.price * 100).rounded()) * quantity }
    private var canAdd: Bool { item.options == nil || selectedOption != nil }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: Brand.icon(for: item.category))
                        .font(.system(size: 30))
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(LinearGradient.brand, in: RoundedRectangle(cornerRadius: 14))
                    Text(item.name).font(.title2.bold())
                    if !item.desc.isEmpty {
                        Text(item.desc).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(Color.clear)

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
                Stepper {
                    HStack {
                        Text("Quantity")
                        Spacer()
                        Text("\(quantity)").font(.body.weight(.semibold).monospacedDigit())
                            .foregroundStyle(Brand.red)
                    }
                } onIncrement: { if quantity < 20 { quantity += 1 } }
                  onDecrement: { if quantity > 1 { quantity -= 1 } }
            }
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                cart.add(item, option: selectedOption,
                         customizations: customizationSummary(), quantity: quantity)
                dismiss()
            } label: {
                HStack {
                    Image(systemName: "cart.badge.plus")
                    Text("Add to Cart")
                    Spacer()
                    Text(dollars(totalCents)).monospacedDigit()
                }
            }
            .buttonStyle(BrandButtonStyle(enabled: canAdd))
            .disabled(!canAdd)
            .padding(.horizontal)
            .padding(.bottom, 8)
            .background(.ultraThinMaterial)
        }
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
                    .tint(Brand.red)
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
