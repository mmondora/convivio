//
//  ScanView.swift
//  Convivio
//
//  Schermata per scansionare etichette vino
//

import SwiftUI
import PhotosUI

struct ScanView: View {
    @StateObject private var viewModel = ScanViewModel()
    @State private var showingCamera = false
    @State private var showingPhotoLibrary = false
    @State private var showingConfirmation = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if viewModel.isProcessing {
                    processingView
                } else if let extraction = viewModel.extraction {
                    confirmationView(extraction)
                } else {
                    captureView
                }
            }
            .padding()
            .navigationTitle("Aggiungi Vino")
            .alert("Errore", isPresented: .constant(viewModel.error != nil)) {
                Button("OK") { viewModel.error = nil }
            } message: {
                Text(viewModel.error ?? "")
            }
            .sheet(isPresented: $showingCamera) {
                CameraView(image: $viewModel.capturedImage)
            }
            .photosPicker(
                isPresented: $showingPhotoLibrary,
                selection: $viewModel.selectedPhoto,
                matching: .images
            )
            .onChange(of: viewModel.capturedImage) { _, newValue in
                if newValue != nil {
                    Task { await viewModel.processImage() }
                }
            }
            .onChange(of: viewModel.selectedPhoto) { _, _ in
                Task { await viewModel.loadSelectedPhoto() }
            }
        }
    }
    
    // MARK: - Capture View
    
    private var captureView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Instructions
            VStack(spacing: 12) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 80))
                    .foregroundStyle(.secondary)
                
                Text("Fotografa l'etichetta")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Inquadra l'etichetta frontale del vino.\nL'AI estrarrà automaticamente le informazioni.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            // Capture buttons
            VStack(spacing: 16) {
                Button {
                    showingCamera = true
                } label: {
                    Label("Scatta foto", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Button {
                    showingPhotoLibrary = true
                } label: {
                    Label("Scegli dalla libreria", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Processing View
    
    private var processingView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            if let image = viewModel.capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(radius: 4)
            }
            
            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.5)
                
                Text("Analisi in corso...")
                    .font(.headline)
                
                Text("Estrazione testo dall'etichetta\ne interpretazione AI")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Confirmation View
    
    private func confirmationView(_ extraction: ExtractionResult) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Confidence indicator
                HStack {
                    Circle()
                        .fill(confidenceColor(extraction.overallConfidence))
                        .frame(width: 12, height: 12)
                    
                    Text("Confidenza: \(Int(extraction.overallConfidence * 100))%")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                }
                
                // Extracted fields
                VStack(spacing: 16) {
                    ExtractedFieldRow(
                        label: "Nome",
                        field: extraction.extractedFields.name,
                        binding: $viewModel.editedName
                    )
                    
                    ExtractedFieldRow(
                        label: "Produttore",
                        field: extraction.extractedFields.producer,
                        binding: $viewModel.editedProducer
                    )
                    
                    ExtractedFieldRow(
                        label: "Annata",
                        field: extraction.extractedFields.vintage,
                        binding: $viewModel.editedVintage
                    )
                    
                    // Wine type picker
                    HStack {
                        Text("Tipo")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Picker("Tipo", selection: $viewModel.editedType) {
                            ForEach(WineType.allCases) { type in
                                Text("\(type.icon) \(type.displayName)").tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    
                    ExtractedFieldRow(
                        label: "Regione",
                        field: extraction.extractedFields.region,
                        binding: $viewModel.editedRegion
                    )
                    
                    ExtractedFieldRow(
                        label: "Paese",
                        field: extraction.extractedFields.country,
                        binding: $viewModel.editedCountry
                    )
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Similar wines warning
                if !viewModel.suggestedMatches.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Vini simili in cantina", systemImage: "exclamationmark.triangle")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                        
                        ForEach(viewModel.suggestedMatches) { wine in
                            Text("• \(wine.displayName)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                // Action buttons
                VStack(spacing: 12) {
                    Button {
                        Task { await viewModel.saveWine() }
                    } label: {
                        Label("Salva in cantina", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(viewModel.editedName.isEmpty)
                    
                    Button {
                        viewModel.reset()
                    } label: {
                        Text("Scansiona altro")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
        }
    }
    
    private func confidenceColor(_ confidence: Double) -> Color {
        switch confidence {
        case 0.8...1.0: return .green
        case 0.5..<0.8: return .yellow
        default: return .red
        }
    }
}

// MARK: - Extracted Field Row

struct ExtractedFieldRow: View {
    let label: String
    let field: ExtractedField?
    @Binding var binding: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if let confidence = field?.confidence {
                    Spacer()
                    Text("\(Int(confidence * 100))%")
                        .font(.caption2)
                        .foregroundStyle(confidence > 0.7 ? .green : .orange)
                }
            }
            
            TextField(label, text: $binding)
                .textFieldStyle(.roundedBorder)
        }
    }
}

// MARK: - Camera View (Placeholder)

struct CameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) var dismiss
    
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
                parent.image = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - View Model

@MainActor
class ScanViewModel: ObservableObject {
    @Published var capturedImage: UIImage?
    @Published var selectedPhoto: PhotosPickerItem?
    @Published var isProcessing = false
    @Published var isSaving = false
    @Published var extraction: ExtractionResult?
    @Published var suggestedMatches: [Wine] = []
    @Published var error: String?

    // Edited fields
    @Published var editedName = ""
    @Published var editedProducer = ""
    @Published var editedVintage = ""
    @Published var editedType: WineType = .red
    @Published var editedRegion = ""
    @Published var editedCountry = ""

    private let firebase = FirebaseService.shared

    func loadSelectedPhoto() async {
        guard let item = selectedPhoto else { return }

        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                capturedImage = image
                await processImage()
            }
        } catch {
            self.error = "Impossibile caricare la foto"
        }
    }

    func processImage() async {
        guard let image = capturedImage else { return }

        isProcessing = true
        defer { isProcessing = false }

        do {
            // Upload image to Firebase Storage
            guard let userId = AuthManager.shared.user?.uid else {
                self.error = "Devi effettuare l'accesso"
                return
            }

            let imagePath = "users/\(userId)/scans/\(UUID().uuidString).jpg"
            let imageUrl = try await firebase.uploadImage(image, path: imagePath)

            // Call Cloud Function for extraction
            extraction = try await firebase.extractWineLabel(imageUrl: imageUrl.absoluteString)

            // Populate edit fields
            editedName = extraction?.extractedFields.name?.value ?? ""
            editedProducer = extraction?.extractedFields.producer?.value ?? ""
            editedVintage = extraction?.extractedFields.vintage?.value ?? ""
            editedRegion = extraction?.extractedFields.region?.value ?? ""
            editedCountry = extraction?.extractedFields.country?.value ?? ""

            if let typeStr = extraction?.extractedFields.type?.value,
               let type = WineType(rawValue: typeStr) {
                editedType = type
            }

            // Search for similar wines in catalog
            if !editedName.isEmpty {
                suggestedMatches = try await firebase.searchWines(query: editedName)
            }

        } catch {
            self.error = error.localizedDescription
        }
    }

    func saveWine() async {
        guard !editedName.isEmpty else {
            error = "Il nome del vino è obbligatorio"
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            guard let userId = AuthManager.shared.user?.uid else {
                self.error = "Devi effettuare l'accesso"
                return
            }

            // 1. Create Wine document
            let wine = Wine(
                id: nil,
                name: editedName,
                producer: editedProducer.isEmpty ? nil : editedProducer,
                vintage: Int(editedVintage),
                type: editedType,
                region: editedRegion.isEmpty ? nil : editedRegion,
                country: editedCountry.isEmpty ? nil : editedCountry,
                grapes: nil,
                alcoholContent: nil,
                description: nil,
                createdAt: nil,
                createdBy: userId
            )

            let wineId = try await firebase.createWine(wine)

            // 2. Get or create default cellar and location
            let cellar = try await firebase.getOrCreateDefaultCellar()
            guard let cellarId = cellar.id else {
                throw FirebaseError.notFound
            }

            let locations = try await firebase.getLocations(cellarId: cellarId)
            guard let locationId = locations.first?.id else {
                throw FirebaseError.notFound
            }

            // 3. Add bottle to cellar
            try await firebase.addBottle(to: cellarId, wineId: wineId, locationId: locationId, price: nil)

            reset()

        } catch {
            self.error = error.localizedDescription
        }
    }

    func reset() {
        capturedImage = nil
        selectedPhoto = nil
        extraction = nil
        suggestedMatches = []
        editedName = ""
        editedProducer = ""
        editedVintage = ""
        editedType = .red
        editedRegion = ""
        editedCountry = ""
    }
}

#Preview {
    ScanView()
}
