import SwiftUI

// MARK: - AIS Parameter Picker

struct AISParameterPicker<T: RawRepresentable & CaseIterable & Identifiable & Equatable>: View where T.RawValue == String, T.AllCases: RandomAccessCollection {
    let title: String
    @Binding var selection: T?
    var showScore: Bool = true
    var scoreExtractor: ((T) -> Int)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline.bold())

                Spacer()

                if showScore, let selected = selection, let extractor = scoreExtractor {
                    ScoreBadge(score: extractor(selected))
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(T.allCases), id: \.id) { option in
                        ParameterChip(
                            label: option.rawValue,
                            isSelected: selection == option,
                            score: showScore ? scoreExtractor?(option) : nil
                        ) {
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                                if selection == option {
                                    selection = nil
                                } else {
                                    selection = option
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Parameter Chip

struct ParameterChip: View {
    let label: String
    let isSelected: Bool
    var score: Int?
    let action: () -> Void

    private var backgroundColor: Color {
        guard isSelected else { return Color(.tertiarySystemBackground) }

        if let score = score {
            return scoreColor(for: score).opacity(0.2)
        }
        return Color.purple.opacity(0.2)
    }

    private var foregroundColor: Color {
        guard isSelected else { return .primary }

        if let score = score {
            return scoreColor(for: score)
        }
        return .purple
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.caption)

                if let score = score, isSelected {
                    Text("(\(score))")
                        .font(.caption2.bold())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? foregroundColor : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func scoreColor(for score: Int) -> Color {
        switch score {
        case 1: return .red
        case 2: return .orange
        case 3: return .yellow
        case 4: return .green
        case 5: return .blue
        default: return .purple
        }
    }
}

// MARK: - Score Badge

struct ScoreBadge: View {
    let score: Int

    private var color: Color {
        switch score {
        case 1: return .red
        case 2: return .orange
        case 3: return .yellow
        case 4: return .green
        case 5: return .blue
        default: return .purple
        }
    }

    var body: some View {
        Text("\(score)")
            .font(.caption.bold())
            .foregroundColor(.white)
            .frame(width: 24, height: 24)
            .background(color)
            .clipShape(Circle())
    }
}

// MARK: - AIS Section Header

struct AISSectionHeader: View {
    let title: String
    let icon: String
    var subtitle: String?
    var score: Int?
    var maxScore: Int?

    var body: some View {
        HStack {
            Label(title, systemImage: icon)
                .font(.headline)

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if let score = score, let maxScore = maxScore {
                HStack(spacing: 4) {
                    Text("\(score)")
                        .font(.headline)
                        .foregroundColor(.purple)
                    Text("/\(maxScore)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - AIS Progress Bar

struct AISProgressBar: View {
    let progress: Double // 0.0 - 1.0
    var label: String = "Completamento"

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.caption.bold())
                    .foregroundColor(progressColor)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemGray5))
                        .frame(height: 8)

                    Capsule()
                        .fill(progressColor)
                        .frame(width: geometry.size.width * progress, height: 8)
                        .animation(.spring(response: 0.3), value: progress)
                }
            }
            .frame(height: 8)
        }
    }

    private var progressColor: Color {
        switch progress {
        case 0..<0.3: return .red
        case 0.3..<0.6: return .orange
        case 0.6..<0.8: return .yellow
        case 0.8...1.0: return .green
        default: return .gray
        }
    }
}

// MARK: - AIS Score Display

struct AISScoreDisplay: View {
    let score: Int
    var label: String = "Punteggio"
    var maxScore: Int = 100
    var minScore: Int = 60

    private var normalizedProgress: Double {
        Double(score - minScore) / Double(maxScore - minScore)
    }

    private var scoreColor: Color {
        switch score {
        case 90...100: return .blue
        case 80..<90: return .green
        case 70..<80: return .yellow
        case 60..<70: return .orange
        default: return .red
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)

            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: normalizedProgress)
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.5), value: score)

                VStack(spacing: 2) {
                    Text("\(score)")
                        .font(.title.bold())
                        .foregroundColor(scoreColor)

                    Text("/\(maxScore)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 80, height: 80)
        }
    }
}

// MARK: - Olfactory Descriptor Picker

struct OlfactoryDescriptorPicker: View {
    @Binding var selectedDescriptors: [String]
    @State private var customDescriptor = ""
    @State private var expandedCategory: String?

    let categories = DescrizioniOlfattiveAIS.categorie

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Selected descriptors
            if !selectedDescriptors.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Selezionati (\(selectedDescriptors.count))")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)

                    FlowLayout(spacing: 8) {
                        ForEach(selectedDescriptors, id: \.self) { descriptor in
                            SelectedDescriptorChip(descriptor: descriptor) {
                                withAnimation {
                                    selectedDescriptors.removeAll { $0 == descriptor }
                                }
                            }
                        }
                    }
                }
            }

            // Categories
            ForEach(categories.keys.sorted(), id: \.self) { category in
                DisclosureGroup(
                    isExpanded: Binding(
                        get: { expandedCategory == category },
                        set: { if $0 { expandedCategory = category } else { expandedCategory = nil } }
                    )
                ) {
                    FlowLayout(spacing: 6) {
                        ForEach(categories[category] ?? [], id: \.self) { descriptor in
                            DescriptorChip(
                                descriptor: descriptor,
                                isSelected: selectedDescriptors.contains(descriptor)
                            ) {
                                withAnimation {
                                    toggleDescriptor(descriptor)
                                }
                            }
                        }
                    }
                    .padding(.top, 8)
                } label: {
                    HStack {
                        Text(category)
                            .font(.subheadline.bold())

                        Spacer()

                        let count = (categories[category] ?? []).filter { selectedDescriptors.contains($0) }.count
                        if count > 0 {
                            Text("\(count)")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                                .frame(width: 20, height: 20)
                                .background(Color.purple)
                                .clipShape(Circle())
                        }
                    }
                }
            }

            // Custom descriptor input
            HStack {
                TextField("Aggiungi descrittore...", text: $customDescriptor)
                    .textFieldStyle(.roundedBorder)

                Button {
                    addCustomDescriptor()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.purple)
                }
                .disabled(customDescriptor.isEmpty)
            }
        }
    }

    private func toggleDescriptor(_ descriptor: String) {
        if selectedDescriptors.contains(descriptor) {
            selectedDescriptors.removeAll { $0 == descriptor }
        } else {
            selectedDescriptors.append(descriptor)
        }
    }

    private func addCustomDescriptor() {
        let trimmed = customDescriptor.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !selectedDescriptors.contains(trimmed) else { return }
        selectedDescriptors.append(trimmed)
        customDescriptor = ""
    }
}

struct DescriptorChip: View {
    let descriptor: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(descriptor)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isSelected ? Color.purple.opacity(0.2) : Color(.tertiarySystemBackground))
                .foregroundColor(isSelected ? .purple : .primary)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.purple : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

struct SelectedDescriptorChip: View {
    let descriptor: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(descriptor)
                .font(.caption)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.purple.opacity(0.2))
        .foregroundColor(.purple)
        .cornerRadius(12)
    }
}

// MARK: - Flow Layout (for wrapping chips)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)

        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX)
        }

        return (CGSize(width: maxX, height: currentY + lineHeight), positions)
    }
}

// MARK: - Preview

#Preview("AIS Picker") {
    struct PreviewWrapper: View {
        @State private var limpidezza: LimpidezzaAIS?
        @State private var descriptors: [String] = ["Rosa", "Mela"]

        var body: some View {
            ScrollView {
                VStack(spacing: 24) {
                    AISParameterPicker(
                        title: "Limpidezza",
                        selection: $limpidezza,
                        scoreExtractor: { $0.punteggio }
                    )

                    AISProgressBar(progress: 0.65)

                    AISScoreDisplay(score: 78)

                    Divider()

                    OlfactoryDescriptorPicker(selectedDescriptors: $descriptors)
                }
                .padding()
            }
        }
    }

    return PreviewWrapper()
}
