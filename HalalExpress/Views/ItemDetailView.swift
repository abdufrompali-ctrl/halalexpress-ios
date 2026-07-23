import SwiftUI

/// One dish, on paper. Photo, choice of variation, topping/sauce/extra checklists
/// (paid extras show their upcharge), quantity, and a sticky ADD bar that carries
/// the real total. No wizard, no progress bar — one honest scroll.
struct ItemDetailView: View {
    let item: CatalogItem
    @EnvironmentObject private var cart: CartStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedOption: String?
    @State private var selections: [String: Bool] = [:]   // modifier id -> on/off
    @State private var quantity = 1
    @State private var addPita = false                    // client-side add-on shown on the Sauces page
    @State private var addedTrigger = false

    // An empty options array is the same as no options — don't dead-end on it.
    private var options: [String]? {
        guard let o = item.options, !o.isEmpty else { return nil }
        return o
    }
    private var allMods: [Modifier] {
        (item.customize?.toppings ?? []) + (item.customize?.sauces ?? []) + (item.customize?.extras ?? [])
    }
    private var addOnCents: Int {
        allMods.reduce(0) { $0 + ((selections[$1.id] ?? $1.isChecked) ? $1.priceCents : 0) }
    }
    private var baseCents: Int { Int((item.price * 100).rounded()) }
    private var totalCents: Int { (baseCents + addOnCents) * quantity }
    private var canAdd: Bool { options == nil || selectedOption != nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                MenuItemImage(item: item).frame(height: 220).frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(item.name).font(.board(34)).foregroundStyle(Paper.ink)
                        Spacer()
                        Text(dollars(baseCents)).font(.price(18)).foregroundStyle(Paper.ink)
                    }
                    if !item.desc.isEmpty {
                        Text(item.desc).font(.subheadline).foregroundStyle(Paper.inkSoft)
                    }
                }
                .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 8)

                if let options { choiceSection(options) }
                modifierSection("Toppings", item.customize?.toppings)
                saucesSection
                modifierSection("Extras", item.customize?.extras)
                quantitySection
            }
            .padding(.bottom, 12)
        }
        .scrollContentBackground(.hidden)
        .background(Paper.bg.ignoresSafeArea())
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Paper.bg, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .safeAreaInset(edge: .bottom) { addBar }
        .sensoryFeedback(.success, trigger: addedTrigger)
        .onAppear {
            if selections.isEmpty {
                for mod in allMods { selections[mod.id] = mod.isChecked }
            }
            if selectedOption == nil { selectedOption = options?.first }
        }
    }

    // MARK: - Sections

    private func sectionHeader(_ title: String) -> some View {
        VStack(spacing: 0) {
            Rule()
            HStack {
                Text(title.uppercased())
                    .font(.system(.subheadline, design: .default).weight(.heavy)).tracking(1)
                    .foregroundStyle(Paper.ink)
                Spacer()
            }
            .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 8)
        }
    }

    private func choiceSection(_ options: [String]) -> some View {
        VStack(spacing: 0) {
            sectionHeader("Choose")
            ForEach(options, id: \.self) { opt in
                Button { selectedOption = opt } label: {
                    HStack(spacing: 12) {
                        Image(systemName: selectedOption == opt ? "largecircle.fill.circle" : "circle")
                            .foregroundStyle(selectedOption == opt ? Paper.red : Paper.inkFaint)
                        Text(opt).foregroundStyle(Paper.ink)
                        Spacer()
                    }
                    .padding(.horizontal, 20).padding(.vertical, 13).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Rule().padding(.leading, 20)
            }
        }
    }

    @ViewBuilder
    private func modifierSection(_ title: String, _ mods: [Modifier]?) -> some View {
        if let mods, !mods.isEmpty {
            VStack(spacing: 0) {
                sectionHeader(title)
                ForEach(mods) { mod in
                    modRow(mod, label: mod.label)
                    Rule().padding(.leading, 20)
                }
            }
        }
    }

    /// One toggle row for a modifier (checkbox + label + optional upcharge).
    private func modRow(_ mod: Modifier, label: String) -> some View {
        let on = selections[mod.id] ?? mod.isChecked
        return Button { selections[mod.id] = !on } label: {
            HStack(spacing: 12) {
                Image(systemName: on ? "checkmark.square.fill" : "square")
                    .foregroundStyle(on ? Paper.red : Paper.inkFaint)
                Text(label).foregroundStyle(Paper.ink)
                Spacer()
                if mod.priceCents > 0 {
                    Text("+\(dollars(mod.priceCents))")
                        .font(.price(14)).foregroundStyle(Paper.inkSoft)
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 13).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    /// Sauces page: dish names shown without the word "Sauce", plus a Pita Bread add-on.
    @ViewBuilder
    private var saucesSection: some View {
        if let sauces = item.customize?.sauces, !sauces.isEmpty {
            VStack(spacing: 0) {
                sectionHeader("Sauces")
                ForEach(sauces) { mod in
                    modRow(mod, label: sauceDisplay(mod.label))
                    Rule().padding(.leading, 20)
                }
                Button { addPita.toggle() } label: {
                    HStack(spacing: 12) {
                        Image(systemName: addPita ? "checkmark.square.fill" : "square")
                            .foregroundStyle(addPita ? Paper.red : Paper.inkFaint)
                        Text("Pita Bread").foregroundStyle(Paper.ink)
                        Spacer()
                    }
                    .padding(.horizontal, 20).padding(.vertical, 13).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(addPita ? .isSelected : [])
                Rule().padding(.leading, 20)
            }
        }
    }

    /// Trim "Sauce" from a modifier label for display ("White Sauce" -> "White").
    private func sauceDisplay(_ label: String) -> String {
        let s = label.replacingOccurrences(of: " Sauce", with: "")
                     .replacingOccurrences(of: "Sauce", with: "")
                     .trimmingCharacters(in: .whitespaces)
        return s.isEmpty ? label : s
    }

    private var quantitySection: some View {
        VStack(spacing: 0) {
            Rule()
            HStack {
                Text("Quantity")
                    .font(.system(.body, design: .default).weight(.semibold))
                    .foregroundStyle(Paper.ink)
                Spacer()
                Stepper(value: $quantity, in: 1...20) {
                    Text("\(quantity)").font(.price(17)).foregroundStyle(Paper.red)
                }
                .fixedSize()
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
        }
    }

    // MARK: - Add bar

    private var addBar: some View {
        Button {
            cart.add(item, option: selectedOption, customizations: customizationSummary(),
                     addOnCents: addOnCents, quantity: quantity)
            addedTrigger.toggle()
            dismiss()
        } label: {
            HStack {
                Text("Add to order")
                Spacer()
                Text(dollars(totalCents)).font(.price(17))
            }
        }
        .buttonStyle(SignButtonStyle(enabled: canAdd))
        .disabled(!canAdd)
        .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 8)
        .background(Paper.bg)
        .overlay(alignment: .top) { Rule() }
    }

    /// Diff selections against defaults into the kitchen-ticket note, matching the
    /// website: "No Lettuce, Add Corn".
    private func customizationSummary() -> String? {
        var parts: [String] = []
        for mod in allMods {
            let on = selections[mod.id] ?? mod.isChecked
            if mod.isChecked && !on { parts.append("No \(mod.label)") }
            if !mod.isChecked && on { parts.append("Add \(mod.label)") }
        }
        if addPita { parts.append("Add Pita Bread") }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
}
