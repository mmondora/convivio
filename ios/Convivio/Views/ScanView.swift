import SwiftUI
import PhotosUI

struct ScanView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var firebaseService: FirebaseService

    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isProcessing = false
    @State private var extractionResult: ExtractWineResponse?
    @State private var showCamera = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Instructions
                    VStack(spacing: 12) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 60))
                            .foregroundColor(.purple)

                        Text("Scansiona Etichetta")
                            .font(.title2.bold())

                        Text("Fotografa l'etichetta di un vino per estrarre automaticamente le informazioni")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()

                    // Image preview or capture buttons
                    if let image = selectedImage {
                        VStack(spacing: 16) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 300)
                                .cornerRadius(12)

                            HStack(spacing: 16) {
                                Button {
                                    selectedImage = nil
                                    extractionResult = nil
                                } label: {
                                    Label("Riprova", systemImage: "arrow.counterclockwise")
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(Color(.tertiarySystemBackground))
                                        .cornerRadius(12)
                                }

                                if !isProcessing && extractionResult == nil {
                                    Button {
                                        Task { await processImage() }
                                    } label: {
                                        Label("Analizza", systemImage: "wand.and.stars")
                                            .padding()
                                            .frame(maxWidth: .infinity)
                                            .background(.purple.gradient)
                                            .foregroundColor(.white)
                                            .cornerRadius(12)
                                    }
                                }
                            }
                        }
                        .padding()
                    } else {
                        HStack(spacing: 16) {
                            // Camera button
                            Button {
                                showCamera = true
                            } label: {
                                VStack(spacing: 12) {
                                    Image(systemName: "camera.fill")
                                        .font(.title)
                                    Text("Fotocamera")
                                        .font(.subheadline)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 32)
                                .background(Color(.tertiarySystemBackground))
                                .cornerRadius(12)
                            }

                            // Gallery button
                            PhotosPicker(
                                selection: $selectedItem,
                                matching: .images
                            ) {
                                VStack(spacing: 12) {
                                    Image(systemName: "photo.on.rectangle")
                                        .font(.title)
                                    Text("Galleria")
                                        .font(.subheadline)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 32)
                                .background(Color(.tertiarySystemBackground))
                                .cornerRadius(12)
                            }
                        }
                        .padding()
                    }

                    // Processing indicator
                    if isProcessing {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)

                            Text("Analisi in corso...")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    }

                    // Error
                    if let error = error {
                        Text(error)
                            .foregroundColor(.red)
                            .padding()
                    }

                    // Results
                    if let result = extractionResult {
                        ExtractionResultView(result: result)
                    }

                    Spacer()
                }
            }
            .navigationTitle("Scansiona")
            .onChange(of: selectedItem) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        selectedImage = image
                        extractionResult = nil
                    }
                }
            }
            .sheet(isPresented: $showCamera) {
                CameraView(image: $selectedImage)
            }
        }
    }

    private func processImage() async {
        guard let image = selectedImage,
              let userId = authManager.currentUser?.uid else { return }

        isProcessing = true
        error = nil

        do {
            // Upload image
            guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                throw ScanError.imageConversionFailed
            }

            let path = "scans/\(userId)/\(UUID().uuidString).jpg"
            let photoUrl = try await firebaseService.uploadPhoto(imageData, path: path)

            // Extract wine info
            extractionResult = try await firebaseService.extractWineFromPhoto(
                photoUrl: photoUrl,
                userId: userId
            )

            if extractionResult?.success == false {
                error = extractionResult?.error ?? "Estrazione fallita"
            }
        } catch {
            self.error = "Errore: \(error.localizedDescription)"
        }

        isProcessing = false
    }
}

enum ScanError: LocalizedError {
    case imageConversionFailed

    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            return "Impossibile convertire l'immagine"
        }
    }
}

struct ExtractionResultView: View {
    @EnvironmentObject var firebaseService: FirebaseService
    @Environment(\.dismiss) private var dismiss

    let result: ExtractWineResponse
    @State private var showAddBottle = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Risultato Estrazione")
                    .font(.headline)

                Spacer()

                if let confidence = result.extraction?.overallConfidence {
                    ConfidenceBadge(confidence: confidence)
                }
            }

            if let extraction = result.extraction {
                VStack(spacing: 12) {
                    if let name = extraction.extractedFields.name {
                        ExtractedFieldRow(
                            label: "Nome",
                            value: name.value,
                            confidence: name.confidence
                        )
                    }

                    if let producer = extraction.extractedFields.producer {
                        ExtractedFieldRow(
                            label: "Produttore",
                            value: producer.value,
                            confidence: producer.confidence
                        )
                    }

                    if let vintage = extraction.extractedFields.vintage {
                        ExtractedFieldRow(
                            label: "Annata",
                            value: vintage.value,
                            confidence: vintage.confidence
                        )
                    }

                    if let type = extraction.extractedFields.type {
                        ExtractedFieldRow(
                            label: "Tipo",
                            value: type.value,
                            confidence: type.confidence
                        )
                    }

                    if let region = extraction.extractedFields.region {
                        ExtractedFieldRow(
                            label: "Regione",
                            value: region.value,
                            confidence: region.confidence
                        )
                    }

                    if let grapes = extraction.extractedFields.grapes {
                        ExtractedFieldRow(
                            label: "Vitigni",
                            value: grapes.value.joined(separator: ", "),
                            confidence: grapes.confidence
                        )
                    }
                }
            }

            // Suggested matches
            if let matches = result.suggestedMatches, !matches.isEmpty {
                Divider()

                Text("Vini Simili in Cantina")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                ForEach(matches) { wine in
                    HStack {
                        Text(wine.type.icon)
                        VStack(alignment: .leading) {
                            Text(wine.name)
                                .font(.subheadline)
                            if let producer = wine.producer {
                                Text(producer)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }

            // Add button
            Button {
                showAddBottle = true
            } label: {
                Label("Aggiungi alla Cantina", systemImage: "plus.circle")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.purple.gradient)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding()
        .sheet(isPresented: $showAddBottle) {
            if let extraction = result.extraction {
                AddBottleFromScanView(extraction: extraction)
            }
        }
    }
}

struct ExtractedFieldRow: View {
    let label: String
    let value: String
    let confidence: Double

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)

            Text(value)
                .fontWeight(.medium)

            Spacer()

            Circle()
                .fill(confidenceColor)
                .frame(width: 8, height: 8)
        }
    }

    private var confidenceColor: Color {
        if confidence >= 0.8 {
            return .green
        } else if confidence >= 0.5 {
            return .yellow
        } else {
            return .red
        }
    }
}

struct ConfidenceBadge: View {
    let confidence: Double

    var body: some View {
        Text("\(Int(confidence * 100))%")
            .font(.caption.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(confidenceColor)
            .cornerRadius(8)
    }

    private var confidenceColor: Color {
        if confidence >= 0.8 {
            return .green
        } else if confidence >= 0.5 {
            return .orange
        } else {
            return .red
        }
    }
}

struct AddBottleFromScanView: View {
    @EnvironmentObject var firebaseService: FirebaseService
    @Environment(\.dismiss) private var dismiss

    let extraction: ExtractionResult

    @State private var name: String
    @State private var producer: String
    @State private var vintage: String
    @State private var selectedType: WineType
    @State private var region: String
    @State private var country: String
    @State private var quantity = 1
    @State private var price = ""
    @State private var isLoading = false

    init(extraction: ExtractionResult) {
        self.extraction = extraction
        let fields = extraction.extractedFields

        _name = State(initialValue: fields.name?.value ?? "")
        _producer = State(initialValue: fields.producer?.value ?? "")
        _vintage = State(initialValue: fields.vintage?.value ?? "")
        _region = State(initialValue: fields.region?.value ?? "")
        _country = State(initialValue: fields.country?.value ?? "Italia")

        let typeValue = fields.type?.value ?? "red"
        _selectedType = State(initialValue: WineType(rawValue: typeValue) ?? .red)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Vino") {
                    TextField("Nome del vino *", text: $name)
                    TextField("Produttore", text: $producer)
                    TextField("Annata", text: $vintage)

                    Picker("Tipo", selection: $selectedType) {
                        ForEach(WineType.allCases, id: \.self) { type in
                            Text("\(type.icon) \(type.displayName)").tag(type)
                        }
                    }
                }

                Section("Origine") {
                    TextField("Regione", text: $region)
                    TextField("Paese", text: $country)
                }

                Section("Dettagli Acquisto") {
                    Stepper("Quantità: \(quantity)", value: $quantity, in: 1...100)
                    TextField("Prezzo (€)", text: $price)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Conferma Dati")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        Task { await saveBottle() }
                    }
                    .disabled(name.isEmpty || isLoading)
                }
            }
        }
    }

    private func saveBottle() async {
        isLoading = true

        let wine = Wine(
            name: name,
            producer: producer.isEmpty ? nil : producer,
            vintage: vintage.isEmpty ? nil : vintage,
            type: selectedType,
            region: region.isEmpty ? nil : region,
            country: country,
            createdAt: .init(date: Date()),
            updatedAt: .init(date: Date())
        )

        let bottle = Bottle(
            wineId: "",
            cellarId: "",
            purchaseDate: .init(date: Date()),
            purchasePrice: Double(price),
            quantity: quantity,
            status: .available,
            createdAt: .init(date: Date()),
            updatedAt: .init(date: Date())
        )

        do {
            try await firebaseService.addBottle(bottle, wine: wine)
            dismiss()
        } catch {
            print("Error saving bottle: \(error)")
        }

        isLoading = false
    }
}

struct CameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
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

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
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

#Preview {
    ScanView()
        .environmentObject(AuthManager.shared)
        .environmentObject(FirebaseService.shared)
}
