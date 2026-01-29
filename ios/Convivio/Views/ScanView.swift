import SwiftUI
import SwiftData
import PhotosUI

struct ScanView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [AppSettings]

    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isProcessing = false
    @State private var extractionResult: ExtractionResult?
    @State private var errorMessage: String?
    @State private var showCamera = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if let image = selectedImage {
                    // Show selected image and results
                    ImagePreviewView(
                        image: image,
                        extractionResult: extractionResult,
                        isProcessing: isProcessing,
                        errorMessage: errorMessage,
                        onSave: saveWine,
                        onRetry: { selectedImage = nil; extractionResult = nil; errorMessage = nil }
                    )
                } else {
                    // Show scan options
                    ScanOptionsView(
                        selectedItem: $selectedItem,
                        showCamera: $showCamera
                    )
                }
            }
            .navigationTitle("Scansiona Etichetta")
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        selectedImage = image
                        await processImage(image)
                    }
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraView { image in
                    selectedImage = image
                    Task { await processImage(image) }
                }
            }
        }
    }

    private func processImage(_ image: UIImage) async {
        isProcessing = true
        errorMessage = nil

        do {
            extractionResult = try await OpenAIService.shared.extractWineFromPhoto(image)
        } catch {
            errorMessage = error.localizedDescription
        }

        isProcessing = false
    }

    private func saveWine() {
        guard let result = extractionResult else { return }

        let wineType: WineType
        if let typeStr = result.type {
            wineType = WineType(rawValue: typeStr) ?? .red
        } else {
            wineType = .red
        }

        let wine = Wine(
            name: result.name ?? "Vino sconosciuto",
            producer: result.producer,
            vintage: result.vintage,
            type: wineType,
            region: result.region,
            country: result.country ?? "Italia",
            grapes: result.grapes ?? [],
            alcohol: result.alcohol
        )

        let bottle = Bottle(
            wine: wine,
            quantity: 1,
            purchaseDate: Date()
        )

        modelContext.insert(wine)
        modelContext.insert(bottle)
        try? modelContext.save()

        // Reset state
        selectedImage = nil
        selectedItem = nil
        extractionResult = nil
    }
}

struct ScanOptionsView: View {
    @Binding var selectedItem: PhotosPickerItem?
    @Binding var showCamera: Bool

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "camera.viewfinder")
                .font(.system(size: 80))
                .foregroundColor(.purple.opacity(0.6))

            VStack(spacing: 8) {
                Text("Scansiona un'etichetta")
                    .font(.title2.bold())

                Text("Fotografa l'etichetta di una bottiglia per aggiungerla automaticamente alla cantina")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 16) {
                Button {
                    showCamera = true
                } label: {
                    Label("Scatta Foto", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }

                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Label("Scegli dalla Libreria", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }
}

struct ImagePreviewView: View {
    let image: UIImage
    let extractionResult: ExtractionResult?
    let isProcessing: Bool
    let errorMessage: String?
    let onSave: () -> Void
    let onRetry: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Image preview
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
                    .cornerRadius(12)
                    .padding(.horizontal)

                if isProcessing {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Analizzando l'etichetta...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else if let error = errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)

                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        Button("Riprova") {
                            onRetry()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                } else if let result = extractionResult {
                    // Extraction results
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Informazioni Rilevate")
                            .font(.headline)

                        ExtractionRow(label: "Nome", value: result.name)
                        ExtractionRow(label: "Produttore", value: result.producer)
                        ExtractionRow(label: "Annata", value: result.vintage)
                        ExtractionRow(label: "Tipo", value: result.type)
                        ExtractionRow(label: "Regione", value: result.region)
                        ExtractionRow(label: "Paese", value: result.country)

                        if let grapes = result.grapes, !grapes.isEmpty {
                            ExtractionRow(label: "Vitigni", value: grapes.joined(separator: ", "))
                        }

                        if let alcohol = result.alcohol {
                            ExtractionRow(label: "Gradazione", value: String(format: "%.1f%%", alcohol))
                        }

                        HStack {
                            Text("Confidenza")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(String(format: "%.0f%%", result.confidence * 100))
                                .foregroundColor(result.confidence > 0.7 ? .green : .orange)
                                .fontWeight(.medium)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    // Action buttons
                    HStack(spacing: 16) {
                        Button {
                            onRetry()
                        } label: {
                            Text("Annulla")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.tertiarySystemBackground))
                                .foregroundColor(.primary)
                                .cornerRadius(12)
                        }

                        Button {
                            onSave()
                        } label: {
                            Text("Aggiungi alla Cantina")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.purple)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                }

                Spacer(minLength: 32)
            }
        }
    }
}

struct ExtractionRow: View {
    let label: String
    let value: String?

    var body: some View {
        if let value = value, !value.isEmpty {
            HStack {
                Text(label)
                    .foregroundColor(.secondary)
                Spacer()
                Text(value)
                    .fontWeight(.medium)
            }
        }
    }
}

// Simple Camera View using UIImagePickerController
struct CameraView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView

        init(_ parent: CameraView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onCapture(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    ScanView()
        .modelContainer(for: [Wine.self, Bottle.self, AppSettings.self], inMemory: true)
}
