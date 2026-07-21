import SwiftUI

struct ItemDetailView: View {
    let item: CatalogItem
    @EnvironmentObject private var cart: CartStore
    @Environment(\.dismiss) private var dismiss

    private enum Step: Hashable {
        case choice, toppings, sauces, extras, review
    }

    @State private var selectedOption: String?
    @State private var selections: [String: Bool] = [:]   // modifier id -> on/off
    @State private var quantity = 1
    @State private var stepIndex = 0
    @State private var addedTrigger = false

    // Steps are derived from what the item actually offers; Review is always last.
    private var steps: [Step] {
        var s: [Step] = []
        if item.options != nil { s.append(.choice) }
        if !(item.customize?.toppings ?? []).isEmpty { s.append(.toppings) }
        if !(item.customize?.sauces ?? []).isEmpty { s.append(.sauces) }
        if !(item.customize?.extras ?? []).isEmpty { s.append(.extras) }
        s.append(.review)
        return s
    }
    private var isBuilder: Bool { steps.count > 1 }
    private var currentStep: Step { steps[min(stepIndex, steps.count - 1)] }

    private var totalCents: Int { Int((item.price * 100).rounded()) * quantity }
    private var canAdd: Bool { item.options == nil || selectedOption != nil }

    var body: some View {
        Form {
            Section {
                MenuItemImage(item: item, corner: 16, iconSize: 48)
                    .frame(height: isBuilder ? 140 : 190)
                    .frame(maxWidth: .infinity)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            if isBuilder {
                Section {
                    stepHeader
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                stepContent

                Section {
                    HStack {
                        if stepIndex > 0 {
                            Button {
                                withAnimation(.snappy) { stepIndex -= 1 }
                            } label: {
                                Label("Back", systemImage: "chevron.left")
                            }
                            .buttonStyle(.borderless)
                        }
                        Spacer()
                        if stepIndex < steps.count - 1 {
                            Button {
                                withAnimation(.snappy) { stepIndex += 1 }
                            } label: {
                                Label("Next", systemImage: "chevron.right")
                                    .labelStyle(.titleAndIcon)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Brand.red)
                            .disabled(currentStep == .choice && selectedOption == nil)
                        }
                    }
                    .listRowBackground(Color.clear)
                }
            } else {
                simpleContent
            }
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                cart.add(item, option: selectedOption,
                         customizations: customizationSummary(), quantity: quantity)
                addedTrigger.toggle()
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
        .sensoryFeedback(.success, trigger: addedTrigger)
        .onAppear {
            if selections.isEmpty, let c = item.customize {
                for mod in (c.toppings ?? []) + (c.sauces ?? []) + (c.extras ?? []) {
                    selections[mod.id] = mod.isChecked
                }
            }
            if selectedOption == nil { selectedOption = item.options?.first }
        }
    }

    // MARK: - Builder steps

    private var stepHeader: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(steps.indices, id: \.self) { i in
                    Capsule()
                        .fill(i <= stepIndex ? Brand.red : Color.gray.opacity(0.25))
                        .frame(height: 5)
                }
            }
            HStack {
                Text(stepTitle(currentStep))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Brand.red)
                Spacer()
                Text("Step \(stepIndex + 1) of \(steps.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func stepTitle(_ step: Step) -> String {
        switch step {
        case .choice:   return "Make It Yours"
        case .toppings: return "Pick Your Toppings"
        case .sauces:   return "Sauce It Up"
        case .extras:   return "Any Extras?"
        case .review:   return "Review Your \(item.name)"
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case .choice:
            if let options = item.options {
                Section("Choice") {
                    Picker("Option", selection: $selectedOption) {
                        ForEach(options, id: \.self) { Text($0).tag(Optional($0)) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
        case .toppings:
            modifierSection("Toppings", item.customize?.toppings)
        case .sauces:
            modifierSection("Sauces", item.customize?.sauces)
        case .extras:
            modifierSection("Extras", item.customize?.extras)
        case .review:
            Section("Your Order") {
                if let selectedOption {
                    LabeledContent("Choice", value: selectedOption)
                }
                LabeledContent("Customizations",
                               value: customizationSummary() ?? "As served")
                Stepper {
                    HStack {
                        Text("Quantity")
                        Spacer()
                        Text("\(quantity)")
                            .font(.body.weight(.semibold).monospacedDigit())
                            .foregroundStyle(Brand.red)
                    }
                } onIncrement: { if quantity < 20 { quantity += 1 } }
                  onDecrement: { if quantity > 1 { quantity -= 1 } }
            }
        }
    }

    // MARK: - Simple (non-customizable) layout

    @ViewBuilder
    private var simpleContent: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text(item.name).font(.title2.bold())
                if !item.desc.isEmpty {
                    Text(item.desc).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 2)
        }
        .listRowBackground(Color.clear)

        Section {
            Stepper {
                HStack {
                    Text("Quantity")
                    Spacer()
                    Text("\(quantity)")
                        .font(.body.weight(.semibold).monospacedDigit())
                        .foregroundStyle(Brand.red)
                }
            } onIncrement: { if quantity < 20 { quantity += 1 } }
              onDecrement: { if quantity > 1 { quantity -= 1 } }
        }
    }

    @ViewBuilder
    private func modifierSection(_ title: String, _ mods: [Modifier]?) -> some View {
        if let mods, !mods.isEmpty {
            Section(title) {
                ForEach(mods) { mod in
                    let on = selections[mod.id] ?? mod.isChecked
                    Button {
                        selections[mod.id] = !on
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: on ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(on ? Brand.red : Color.secondary)
                            Text(mod.label).foregroundStyle(.primary)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
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
