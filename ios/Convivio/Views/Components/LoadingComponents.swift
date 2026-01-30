import SwiftUI

// MARK: - Skeleton View

/// A shimmer effect view for loading placeholders
struct SkeletonView: View {
    @State private var isAnimating = false

    let width: CGFloat?
    let height: CGFloat

    init(width: CGFloat? = nil, height: CGFloat = 20) {
        self.width = width
        self.height = height
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.gray.opacity(0.2))
            .frame(width: width, height: height)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                .clear,
                                .white.opacity(0.4),
                                .clear
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(x: isAnimating ? 200 : -200)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
    }
}

// MARK: - Skeleton Row

/// A skeleton placeholder for a list row
struct SkeletonRowView: View {
    var body: some View {
        HStack(spacing: 12) {
            SkeletonView(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 8) {
                SkeletonView(width: 150, height: 16)
                SkeletonView(width: 100, height: 12)
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Skeleton List

/// A skeleton placeholder for a list of items
struct SkeletonListView: View {
    let rowCount: Int

    init(rowCount: Int = 5) {
        self.rowCount = rowCount
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<rowCount, id: \.self) { _ in
                SkeletonRowView()
                Divider()
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Contextual Progress View

/// A progress indicator with contextual message
struct ContextualProgressView: View {
    let message: String
    let submessage: String?
    let showSpinner: Bool

    init(
        _ message: String,
        submessage: String? = nil,
        showSpinner: Bool = true
    ) {
        self.message = message
        self.submessage = submessage
        self.showSpinner = showSpinner
    }

    var body: some View {
        VStack(spacing: 16) {
            if showSpinner {
                ProgressView()
                    .scaleEffect(1.2)
            }

            VStack(spacing: 4) {
                Text(message)
                    .font(.headline)
                    .foregroundColor(.primary)

                if let sub = submessage {
                    Text(sub)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(24)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
}

// MARK: - Timed Progress View

/// A progress view with automatic timeout
struct TimedProgressView: View {
    let message: String
    let timeout: TimeInterval
    let onTimeout: () -> Void

    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var showTimeoutWarning = false

    init(
        message: String,
        timeout: TimeInterval = 30,
        onTimeout: @escaping () -> Void
    ) {
        self.message = message
        self.timeout = timeout
        self.onTimeout = onTimeout
    }

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            Text(message)
                .font(.headline)

            if showTimeoutWarning {
                Text("L'operazione sta richiedendo piu tempo del previsto...")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)
            } else if elapsedTime > 5 {
                Text("Attendere prego...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(24)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .onAppear {
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsedTime += 1

            if elapsedTime >= timeout * 0.7 {
                showTimeoutWarning = true
            }

            if elapsedTime >= timeout {
                timer?.invalidate()
                onTimeout()
            }
        }
    }
}

// MARK: - Loading Overlay Modifier

struct LoadingOverlayModifier: ViewModifier {
    let isLoading: Bool
    let message: String

    func body(content: Content) -> some View {
        ZStack {
            content
                .disabled(isLoading)
                .blur(radius: isLoading ? 2 : 0)

            if isLoading {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()

                ContextualProgressView(message)
            }
        }
    }
}

extension View {
    func loadingOverlay(isLoading: Bool, message: String = "Caricamento...") -> some View {
        modifier(LoadingOverlayModifier(isLoading: isLoading, message: message))
    }
}

// MARK: - Menu Generation Progress

/// Progress indicator specifically for menu generation
struct MenuGenerationProgressView: View {
    @State private var currentPhase = 0
    @State private var timer: Timer?

    let phases = [
        ("Analizzo le preferenze...", "fork.knife"),
        ("Consulto la cantina...", "wineglass"),
        ("Creo gli abbinamenti...", "sparkles"),
        ("Finalizzo il menu...", "menucard")
    ]

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color.purple.opacity(0.2), lineWidth: 4)
                    .frame(width: 80, height: 80)

                Circle()
                    .trim(from: 0, to: CGFloat(currentPhase + 1) / CGFloat(phases.count))
                    .stroke(Color.purple, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: currentPhase)

                Image(systemName: phases[currentPhase].1)
                    .font(.title)
                    .foregroundColor(.purple)
            }

            Text(phases[currentPhase].0)
                .font(.headline)
                .animation(.easeInOut, value: currentPhase)

            Text("Fase \(currentPhase + 1) di \(phases.count)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(32)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(20)
        .onAppear {
            startPhaseTimer()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }

    private func startPhaseTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { _ in
            withAnimation {
                currentPhase = (currentPhase + 1) % phases.count
            }
        }
    }
}

// MARK: - Error State View

struct ErrorStateView: View {
    let title: String
    let message: String
    let retryAction: (() -> Void)?

    init(
        title: String = "Si e verificato un errore",
        message: String,
        retryAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.retryAction = retryAction
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.orange)

            Text(title)
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if let retry = retryAction {
                Button(action: retry) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Riprova")
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.top, 8)
            }
        }
        .padding(24)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
}

// MARK: - Timeout Error View

struct TimeoutErrorView: View {
    let onRetry: () -> Void

    var body: some View {
        ErrorStateView(
            title: "Operazione scaduta",
            message: "L'operazione ha richiesto troppo tempo. Verifica la tua connessione e riprova.",
            retryAction: onRetry
        )
    }
}

// MARK: - Previews

#Preview("Skeleton") {
    VStack(spacing: 20) {
        SkeletonView(width: 200, height: 20)
        SkeletonRowView()
        SkeletonListView(rowCount: 3)
    }
    .padding()
}

#Preview("Progress Views") {
    VStack(spacing: 20) {
        ContextualProgressView("Genero il menu...", submessage: "Questo potrebbe richiedere qualche secondo")
        MenuGenerationProgressView()
    }
}

#Preview("Error Views") {
    VStack(spacing: 20) {
        ErrorStateView(message: "Impossibile generare il menu") { }
        TimeoutErrorView { }
    }
}
