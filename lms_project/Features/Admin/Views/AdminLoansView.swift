import SwiftUI

struct AdminLoansView: View {
    @EnvironmentObject var loansVM: AdminLoansViewModel
    @Binding var showProfile: Bool
    @Environment(\.colorScheme) private var colorScheme

    private let columns = [
        GridItem(.flexible(), spacing: Theme.Spacing.lg),
        GridItem(.flexible(), spacing: Theme.Spacing.lg)
    ]

    private var addLoanSheetBinding: Binding<Bool> {
        Binding(
            get: { loansVM.showAddLoanSheet },
            set: { loansVM.showAddLoanSheet = $0 }
        )
    }

    private var editingLoanBinding: Binding<LoanProduct?> {
        Binding(
            get: { loansVM.editingLoan },
            set: { loansVM.editingLoan = $0 }
        )
    }

    private var showActionAlertBinding: Binding<Bool> {
        Binding(
            get: { loansVM.showActionAlert },
            set: { loansVM.showActionAlert = $0 }
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.adaptiveBackground(colorScheme).ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        searchBar
                        header

                        if loansVM.isLoading && loansVM.loanProducts.isEmpty {
                            ProgressView()
                                .frame(maxWidth: .infinity, minHeight: 400)
                        } else if loansVM.filteredProducts.isEmpty {
                            emptyState
                        } else {
                            LazyVGrid(columns: columns, spacing: Theme.Spacing.lg) {
                                ForEach(loansVM.filteredProducts) { product in
                                    LoanProductCard(product: product)
                                }
                            }
                            .padding(.horizontal, Theme.Spacing.lg)
                        }

                        Spacer(minLength: 100)
                    }
                }
                .refreshable {
                    await loansVM.refresh()
                }
            }
            .navigationTitle("Loans")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        if loansVM.isSaving {
                            ProgressView()
                                .controlSize(.small)
                        }

                        Button {
                            loansVM.showAddLoanSheet = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 22, weight: .light))
                                .foregroundStyle(Theme.Colors.primary)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .disabled(loansVM.isSaving)

                        ProfileNavButton(showProfile: $showProfile)
                    }
                }
            }
            .task {
                loansVM.loadData()
            }
            .sheet(isPresented: addLoanSheetBinding) {
                AddLoanSheet()
                    .environmentObject(loansVM)
            }
            .sheet(item: editingLoanBinding) { loan in
                EditLoanSheet(product: loan)
                    .environmentObject(loansVM)
            }
            .alert(loansVM.actionMessage ?? "", isPresented: showActionAlertBinding) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search loan products...", text: $loansVM.searchText)
                .font(Theme.Typography.subheadline)
        }
        .padding(12)
        .background(Theme.Colors.adaptiveSurface(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .stroke(Theme.Colors.adaptiveBorder(colorScheme), lineWidth: 0.5)
        )
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.top, Theme.Spacing.md)
    }

    private var header: some View {
        HStack {
            Text("Loan Products")
                .font(Theme.Typography.title)
            Spacer()
            Text("\(loansVM.filteredProducts.count) live")
                .font(Theme.Typography.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, Theme.Spacing.lg)
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("No loan products found")
                .font(Theme.Typography.headline)
                .foregroundStyle(.secondary)
            Text("Products shown here now come directly from the backend catalog.")
                .font(Theme.Typography.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 400)
    }
}

struct LoanProductCard: View {
    let product: LoanProduct
    @EnvironmentObject var loansVM: AdminLoansViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(alignment: .top) {
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.Radius.md)
                        .fill(Theme.Colors.primary.opacity(0.1))
                        .frame(width: 48, height: 48)
                    Image(systemName: product.icon)
                        .font(.system(size: 22))
                        .foregroundStyle(Theme.Colors.primary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(product.name)
                        .font(Theme.Typography.headline)
                    HStack(spacing: 8) {
                        pill(product.categoryLabel, color: Theme.Colors.primary)
                        pill(product.statusLabel, color: product.isActive ? Theme.Colors.secondary : .orange)
                    }
                }

                Spacer()

                HStack(spacing: Theme.Spacing.sm) {
                    Button { loansVM.editingLoan = product } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.Colors.primary.opacity(0.8))
                            .padding(8)
                            .background(Theme.Colors.primary.opacity(0.05))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Button { loansVM.deleteLoanProduct(product) } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundStyle(.red.opacity(0.7))
                            .padding(8)
                            .background(Color.red.opacity(0.05))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(loansVM.isSaving)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(product.amountRangeDisplay)
                    .font(.system(size: 16, weight: .semibold))
                Text(product.rateDisplay)
                    .font(Theme.Typography.subheadline)
                    .foregroundStyle(.secondary)
                if let rule = product.eligibilityRule {
                    Text("Min age \(rule.minAge) • Bureau \(rule.minBureauScore) • Income \(LoanProduct.currency(rule.minMonthlyIncome))")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack(spacing: 0) {
                cardKPI(title: "Fees", value: "\(product.fees.count)", icon: "percent")
                divider
                cardKPI(title: "Docs", value: "\(product.requiredDocuments.count)", icon: "doc.text")
                divider
                cardKPI(title: "Collateral", value: product.isRequiringCollateral ? "Yes" : "No", icon: "shield")
            }
        }
        .padding(Theme.Spacing.md)
        .cardStyle(colorScheme: colorScheme)
    }

    private func pill(_ label: String, color: Color) -> some View {
        Text(label)
            .font(.system(size: 11, weight: .bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color.opacity(0.1))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.Colors.adaptiveBorder(colorScheme))
            .frame(width: 0.5, height: 24)
            .padding(.horizontal, Theme.Spacing.sm)
    }

    private func cardKPI(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(title)
                    .font(Theme.Typography.caption2)
            }
            .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.Colors.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AddLoanSheet: View {
    @EnvironmentObject var loansVM: AdminLoansViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var draft = LoanDraft.defaultDraft

    var body: some View {
        LoanProductEditor(title: "Add New Loan", draft: $draft, isSaving: loansVM.isSaving) { product in
            loansVM.addLoanProduct(product)
            dismiss()
        }
    }
}

struct EditLoanSheet: View {
    let product: LoanProduct
    @EnvironmentObject var loansVM: AdminLoansViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var draft: LoanDraft

    init(product: LoanProduct) {
        self.product = product
        _draft = State(initialValue: LoanDraft(product: product))
    }

    var body: some View {
        LoanProductEditor(title: "Edit Loan", draft: $draft, isSaving: loansVM.isSaving) { updated in
            loansVM.updateLoanProduct(oldProduct: product, newProduct: updated)
            dismiss()
        }
    }
}

private struct LoanProductEditor: View {
    let title: String
    @Binding var draft: LoanDraft
    let isSaving: Bool
    let onSave: (LoanProduct) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Basic") {
                    TextField("Product name", text: $draft.name)
                    Picker("Category", selection: $draft.category) {
                        ForEach(LoanDraft.availableCategories, id: \.self) { category in
                            Text(LoanDraft.categoryLabel(for: category)).tag(category)
                        }
                    }
                    Picker("Interest type", selection: $draft.interestType) {
                        ForEach(LoanDraft.availableInterestTypes, id: \.self) { type in
                            Text(LoanDraft.interestLabel(for: type)).tag(type)
                        }
                    }
                    Toggle("Requires collateral", isOn: $draft.isRequiringCollateral)
                    Toggle("Visible to borrowers", isOn: $draft.isActive)
                }

                Section("Pricing") {
                    numericField("Base interest rate (%)", text: $draft.baseInterestRate)
                    numericField("Minimum amount", text: $draft.minAmount, prefix: "₹")
                    numericField("Maximum amount", text: $draft.maxAmount, prefix: "₹")
                }

                Section("Eligibility") {
                    integerField("Minimum age", text: $draft.minAge)
                    numericField("Minimum monthly income", text: $draft.minMonthlyIncome, prefix: "₹")
                    integerField("Minimum bureau score", text: $draft.minBureauScore)
                    TextField("Employment types (comma separated)", text: $draft.allowedEmploymentTypes)
                }

                Section("Fees") {
                    ForEach($draft.fees) { $fee in
                        VStack(alignment: .leading, spacing: 12) {
                            Picker("Type", selection: $fee.type) {
                                ForEach(LoanDraft.availableFeeTypes, id: \.self) { type in
                                    Text(LoanDraft.feeTypeLabel(for: type)).tag(type)
                                }
                            }
                            Picker("Calculation", selection: $fee.calcMethod) {
                                ForEach(LoanDraft.availableCalcMethods, id: \.self) { method in
                                    Text(LoanDraft.calcMethodLabel(for: method)).tag(method)
                                }
                            }
                            TextField("Value", text: $fee.value)
                                .keyboardType(.decimalPad)
                        }
                    }
                    .onDelete { draft.fees.remove(atOffsets: $0) }

                    Button("Add Fee") {
                        draft.fees.append(.empty)
                    }
                }

                Section("Required Documents") {
                    ForEach($draft.documents) { $document in
                        VStack(alignment: .leading, spacing: 12) {
                            Picker("Document", selection: $document.requirementType) {
                                ForEach(LoanDraft.availableDocumentTypes, id: \.self) { type in
                                    Text(LoanDraft.documentLabel(for: type)).tag(type)
                                }
                            }
                            Toggle("Mandatory", isOn: $document.isMandatory)
                        }
                    }
                    .onDelete { draft.documents.remove(atOffsets: $0) }

                    Button("Add Document") {
                        draft.documents.append(.empty)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving..." : "Save") {
                        onSave(draft.toProduct())
                    }
                    .disabled(!draft.isValid || isSaving)
                    .fontWeight(.bold)
                }
            }
        }
    }

    private func numericField(_ title: String, text: Binding<String>, prefix: String? = nil) -> some View {
        HStack {
            Text(title)
            Spacer()
            if let prefix {
                Text(prefix).foregroundStyle(.secondary)
            }
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 120)
        }
    }

    private func integerField(_ title: String, text: Binding<String>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", text: text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
        }
    }
}

private struct LoanDraft {
    struct FeeDraft: Identifiable {
        var id = UUID()
        var type: Loan_V1_ProductFeeType
        var calcMethod: Loan_V1_FeeCalcMethod
        var value: String

        static let empty = FeeDraft(type: .processing, calcMethod: .percentage, value: "")
    }

    struct DocumentDraft: Identifiable {
        var id = UUID()
        var requirementType: Loan_V1_DocumentRequirementType
        var isMandatory: Bool

        static let empty = DocumentDraft(requirementType: .identity, isMandatory: true)
    }

    var id: String
    var name: String
    var category: Loan_V1_LoanProductCategory
    var interestType: Loan_V1_InterestType
    var baseInterestRate: String
    var minAmount: String
    var maxAmount: String
    var isRequiringCollateral: Bool
    var isActive: Bool
    var minAge: String
    var minMonthlyIncome: String
    var minBureauScore: String
    var allowedEmploymentTypes: String
    var fees: [FeeDraft]
    var documents: [DocumentDraft]

    static let availableCategories: [Loan_V1_LoanProductCategory] = [.home, .personal, .vehicle, .education]
    static let availableInterestTypes: [Loan_V1_InterestType] = [.fixed, .floating]
    static let availableFeeTypes: [Loan_V1_ProductFeeType] = [.processing, .prepayment, .latePayment]
    static let availableCalcMethods: [Loan_V1_FeeCalcMethod] = [.flat, .percentage]
    static let availableDocumentTypes: [Loan_V1_DocumentRequirementType] = [.identity, .address, .income, .collateral]

    init(
        id: String,
        name: String,
        category: Loan_V1_LoanProductCategory,
        interestType: Loan_V1_InterestType,
        baseInterestRate: String,
        minAmount: String,
        maxAmount: String,
        isRequiringCollateral: Bool,
        isActive: Bool,
        minAge: String,
        minMonthlyIncome: String,
        minBureauScore: String,
        allowedEmploymentTypes: String,
        fees: [FeeDraft],
        documents: [DocumentDraft]
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.interestType = interestType
        self.baseInterestRate = baseInterestRate
        self.minAmount = minAmount
        self.maxAmount = maxAmount
        self.isRequiringCollateral = isRequiringCollateral
        self.isActive = isActive
        self.minAge = minAge
        self.minMonthlyIncome = minMonthlyIncome
        self.minBureauScore = minBureauScore
        self.allowedEmploymentTypes = allowedEmploymentTypes
        self.fees = fees
        self.documents = documents
    }

    static let defaultDraft = LoanDraft(
        id: "",
        name: "",
        category: .home,
        interestType: .fixed,
        baseInterestRate: "8.5",
        minAmount: "100000",
        maxAmount: "5000000",
        isRequiringCollateral: true,
        isActive: true,
        minAge: "21",
        minMonthlyIncome: "25000",
        minBureauScore: "650",
        allowedEmploymentTypes: "Salaried, Self-employed",
        fees: [.init(type: .processing, calcMethod: .percentage, value: "1.0")],
        documents: [.init(requirementType: .identity, isMandatory: true), .init(requirementType: .income, isMandatory: true)]
    )

    init(product: LoanProduct) {
        self.id = product.id
        self.name = product.name
        self.category = product.category
        self.interestType = product.interestType
        self.baseInterestRate = product.baseInterestRate
        self.minAmount = product.minAmount
        self.maxAmount = product.maxAmount
        self.isRequiringCollateral = product.isRequiringCollateral
        self.isActive = product.isActive
        self.minAge = product.eligibilityRule.map { String($0.minAge) } ?? ""
        self.minMonthlyIncome = product.eligibilityRule?.minMonthlyIncome ?? ""
        self.minBureauScore = product.eligibilityRule.map { String($0.minBureauScore) } ?? ""
        self.allowedEmploymentTypes = product.eligibilityRule?.allowedEmploymentTypes.joined(separator: ", ") ?? ""
        self.fees = product.fees.map { .init(type: $0.type, calcMethod: $0.calcMethod, value: $0.value) }
        self.documents = product.requiredDocuments.map { .init(requirementType: $0.requirementType, isMandatory: $0.isMandatory) }
        if fees.isEmpty { fees = [.empty] }
        if documents.isEmpty { documents = [.empty] }
    }

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && Double(baseInterestRate) != nil
        && Double(minAmount.replacingOccurrences(of: ",", with: "")) != nil
        && Double(maxAmount.replacingOccurrences(of: ",", with: "")) != nil
    }

    func toProduct() -> LoanProduct {
        LoanProduct(
            id: id,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category,
            interestType: interestType,
            baseInterestRate: baseInterestRate,
            minAmount: minAmount.replacingOccurrences(of: ",", with: ""),
            maxAmount: maxAmount.replacingOccurrences(of: ",", with: ""),
            isRequiringCollateral: isRequiringCollateral,
            isActive: isActive,
            eligibilityRule: LoanProduct.EligibilityRule(
                id: "",
                minAge: Int(minAge) ?? 0,
                minMonthlyIncome: minMonthlyIncome.replacingOccurrences(of: ",", with: ""),
                minBureauScore: Int(minBureauScore) ?? 0,
                allowedEmploymentTypes: allowedEmploymentTypes
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            ),
            fees: fees.filter { !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.map {
                LoanProduct.Fee(id: "", type: $0.type, calcMethod: $0.calcMethod, value: $0.value)
            },
            requiredDocuments: documents.map {
                LoanProduct.RequiredDocument(id: "", requirementType: $0.requirementType, isMandatory: $0.isMandatory)
            }
        )
    }

    static func categoryLabel(for category: Loan_V1_LoanProductCategory) -> String {
        switch category {
        case .home: return "Home"
        case .personal: return "Personal"
        case .vehicle: return "Vehicle"
        case .education: return "Education"
        case .unspecified, .UNRECOGNIZED(_): return "Other"
        }
    }

    static func interestLabel(for type: Loan_V1_InterestType) -> String {
        switch type {
        case .fixed: return "Fixed"
        case .floating: return "Floating"
        case .unspecified, .UNRECOGNIZED(_): return "Unspecified"
        }
    }

    static func feeTypeLabel(for type: Loan_V1_ProductFeeType) -> String {
        switch type {
        case .processing: return "Processing"
        case .prepayment: return "Prepayment"
        case .latePayment: return "Late Payment"
        case .unspecified, .UNRECOGNIZED(_): return "Other"
        }
    }

    static func calcMethodLabel(for method: Loan_V1_FeeCalcMethod) -> String {
        switch method {
        case .flat: return "Flat Amount"
        case .percentage: return "Percentage"
        case .unspecified, .UNRECOGNIZED(_): return "Other"
        }
    }

    static func documentLabel(for type: Loan_V1_DocumentRequirementType) -> String {
        switch type {
        case .identity: return "Identity"
        case .address: return "Address"
        case .income: return "Income"
        case .collateral: return "Collateral"
        case .unspecified, .UNRECOGNIZED(_): return "Other"
        }
    }
}
