//
//  AppIconGenerator.swift
//  Convivio
//
//  Genera l'icona dell'app usando SF Symbols
//

import SwiftUI

struct AppIconView: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.45, green: 0.15, blue: 0.25), // Burgundy
                    Color(red: 0.25, green: 0.08, blue: 0.15)  // Dark wine
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Wine glass icon
            Image(systemName: "wineglass.fill")
                .font(.system(size: size * 0.5, weight: .regular))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.85, blue: 0.7),  // Champagne gold
                            Color(red: 0.95, green: 0.75, blue: 0.55) // Warm gold
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: .black.opacity(0.3), radius: size * 0.02, x: 0, y: size * 0.01)
        }
        .frame(width: size, height: size)
    }
}

#if DEBUG
struct AppIconGenerator: View {
    @State private var generatedImage: UIImage?
    @State private var isSaving = false
    @State private var showingSaveAlert = false
    @State private var saveMessage = ""

    var body: some View {
        VStack(spacing: 24) {
            Text("App Icon Generator")
                .font(.title)
                .fontWeight(.bold)

            // Preview
            AppIconView(size: 200)
                .clipShape(RoundedRectangle(cornerRadius: 40))

            Text("Anteprima (200x200)")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Size variants
            HStack(spacing: 16) {
                ForEach([60, 120, 180], id: \.self) { size in
                    VStack {
                        AppIconView(size: CGFloat(size))
                            .clipShape(RoundedRectangle(cornerRadius: CGFloat(size) * 0.2))
                        Text("\(size)px")
                            .font(.caption2)
                    }
                }
            }

            Spacer()

            // Export button
            Button {
                exportIcon()
            } label: {
                if isSaving {
                    ProgressView()
                } else {
                    Label("Esporta icona 1024x1024", systemImage: "square.and.arrow.down")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSaving)

            Text("L'icona verrà salvata nella libreria foto")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .alert("Esportazione", isPresented: $showingSaveAlert) {
            Button("OK") { }
        } message: {
            Text(saveMessage)
        }
    }

    @MainActor
    private func exportIcon() {
        isSaving = true

        let renderer = ImageRenderer(content: AppIconView(size: 1024))
        renderer.scale = 1.0

        if let image = renderer.uiImage {
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            saveMessage = "Icona salvata nella libreria foto!"
        } else {
            saveMessage = "Errore durante la generazione dell'icona"
        }

        isSaving = false
        showingSaveAlert = true
    }
}

#Preview {
    AppIconGenerator()
}

#Preview("Icon Only") {
    AppIconView(size: 1024)
}
#endif
