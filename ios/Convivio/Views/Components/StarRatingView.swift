import SwiftUI

// MARK: - Interactive Star Rating View

struct StarRatingView: View {
    @Binding var rating: Double
    var maxRating: Int = 5
    var size: StarSize = .large
    var allowHalfStars: Bool = true
    var onRatingChanged: ((Double) -> Void)?

    @State private var highlightedRating: Double?
    @GestureState private var isDragging = false

    enum StarSize {
        case small, medium, large, extraLarge

        var fontSize: CGFloat {
            switch self {
            case .small: return 16
            case .medium: return 24
            case .large: return 36
            case .extraLarge: return 48
            }
        }

        var spacing: CGFloat {
            switch self {
            case .small: return 2
            case .medium: return 4
            case .large: return 8
            case .extraLarge: return 12
            }
        }
    }

    private var displayRating: Double {
        highlightedRating ?? rating
    }

    var body: some View {
        HStack(spacing: size.spacing) {
            ForEach(1...maxRating, id: \.self) { index in
                starView(for: index)
                    .onTapGesture {
                        handleTap(at: index)
                    }
            }
        }
        .gesture(dragGesture)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Valutazione: \(String(format: "%.1f", rating)) su \(maxRating) stelle")
        .accessibilityValue("\(String(format: "%.1f", rating)) stelle")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                let newRating = min(Double(maxRating), rating + (allowHalfStars ? 0.5 : 1.0))
                rating = newRating
                onRatingChanged?(newRating)
            case .decrement:
                let newRating = max(0, rating - (allowHalfStars ? 0.5 : 1.0))
                rating = newRating
                onRatingChanged?(newRating)
            @unknown default:
                break
            }
        }
    }

    @ViewBuilder
    private func starView(for index: Int) -> some View {
        let starType = starType(for: index)

        Image(systemName: starType)
            .font(.system(size: size.fontSize))
            .foregroundColor(.orange)
            .scaleEffect(highlightedRating != nil && Int(highlightedRating!) == index ? 1.2 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: highlightedRating)
    }

    private func starType(for index: Int) -> String {
        let value = Double(index)
        if displayRating >= value {
            return "star.fill"
        } else if displayRating >= value - 0.5 && allowHalfStars {
            return "star.leadinghalf.filled"
        } else {
            return "star"
        }
    }

    private func handleTap(at index: Int) {
        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
            if allowHalfStars {
                let currentValue = Double(index)
                // If tapping on current full star, make it half
                if rating == currentValue {
                    rating = currentValue - 0.5
                } else {
                    rating = currentValue
                }
            } else {
                rating = Double(index)
            }
            onRatingChanged?(rating)
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($isDragging) { _, state, _ in
                state = true
            }
            .onChanged { value in
                let starWidth = size.fontSize + size.spacing
                let totalWidth = starWidth * CGFloat(maxRating)
                let xPosition = max(0, min(value.location.x, totalWidth))
                let rawRating = (xPosition / totalWidth) * Double(maxRating)

                let newRating: Double
                if allowHalfStars {
                    newRating = (rawRating * 2).rounded() / 2
                } else {
                    newRating = rawRating.rounded()
                }

                highlightedRating = max(0.5, min(Double(maxRating), newRating))
            }
            .onEnded { _ in
                if let highlighted = highlightedRating {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                        rating = highlighted
                        highlightedRating = nil
                        onRatingChanged?(rating)
                    }
                }
            }
    }
}

// MARK: - Display-Only Star Rating

struct StarRatingDisplayView: View {
    let rating: Double
    var maxRating: Int = 5
    var size: StarRatingView.StarSize = .medium
    var showValue: Bool = true

    var body: some View {
        HStack(spacing: size.spacing) {
            ForEach(1...maxRating, id: \.self) { index in
                Image(systemName: starType(for: index))
                    .font(.system(size: size.fontSize))
                    .foregroundColor(.orange)
            }

            if showValue {
                Text(String(format: "%.1f", rating))
                    .font(.system(size: size.fontSize * 0.5, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.leading, 4)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Valutazione: \(String(format: "%.1f", rating)) su \(maxRating) stelle")
    }

    private func starType(for index: Int) -> String {
        let value = Double(index)
        if rating >= value {
            return "star.fill"
        } else if rating >= value - 0.5 {
            return "star.leadinghalf.filled"
        } else {
            return "star"
        }
    }
}

// MARK: - Compact Mini Star Rating

struct MiniStarRatingView: View {
    let rating: Double

    var body: some View {
        HStack(spacing: 1) {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: starType(for: index))
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
            }
        }
    }

    private func starType(for index: Int) -> String {
        let value = Double(index)
        if rating >= value {
            return "star.fill"
        } else if rating >= value - 0.5 {
            return "star.leadinghalf.filled"
        } else {
            return "star"
        }
    }
}

// MARK: - Rating Description

extension Double {
    var ratingDescription: String {
        switch self {
        case 0..<1: return "Non valutato"
        case 1..<1.5: return "Scarso"
        case 1.5..<2.5: return "Mediocre"
        case 2.5..<3.5: return "Discreto"
        case 3.5..<4: return "Buono"
        case 4..<4.5: return "Ottimo"
        case 4.5...5: return "Eccezionale"
        default: return ""
        }
    }
}

// MARK: - Preview

#Preview("Interactive") {
    struct PreviewWrapper: View {
        @State private var rating: Double = 3.5

        var body: some View {
            VStack(spacing: 32) {
                Text("Rating: \(String(format: "%.1f", rating))")
                    .font(.headline)

                Text(rating.ratingDescription)
                    .foregroundColor(.secondary)

                StarRatingView(rating: $rating, size: .extraLarge)

                StarRatingView(rating: $rating, size: .large, allowHalfStars: false)

                StarRatingDisplayView(rating: rating, size: .medium)

                MiniStarRatingView(rating: rating)
            }
            .padding()
        }
    }

    return PreviewWrapper()
}
