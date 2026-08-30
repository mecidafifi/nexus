import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct TransferView: View {
    @Environment(\.modelContext) private var context
    @State private var importing = false
    @State private var prepared: PreparedTransfer?
    @State private var preview: TransferPreview?
    @State private var policy: TransferDuplicatePolicy = .skip
    @State private var error: String?
    @State private var result: TransferImportResult?
    @State private var exportDocument: TransferJSONDocument?
    @State private var exporting = false

    var body: some View {
        NavigationStack {
            ZStack {
                TerminalBackground(showGlobe: true)
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("NEXUS // YEREL AKTARIM").font(.system(.largeTitle, design: .monospaced, weight: .bold))
                        TerminalCard("Mac'ten verileri aktar / Study Pack") {
                            Text("Files içinden sizin seçtiğiniz JSON önce tamamen doğrulanır. Önizleme ve açık onay olmadan hiçbir kayıt yazılmaz.")
                                .foregroundStyle(PadTokens.phosphorDim)
                            Button { importing = true } label: {
                                Label("JSON seç ve önizle", systemImage: "doc.badge.plus")
                                    .foregroundStyle(PadTokens.background)
                            }
                                .buttonStyle(.borderedProminent).controlSize(.large).frame(minHeight: PadTokens.minimumTap)
                        }
                        TerminalCard("Desteklenen kaynaklar") {
                            Label("StudyPadTransfer v1: ders, program, oturum, metin notu ve görev", systemImage: "checkmark.shield")
                            Label("NEXUS Mac v1–v9 JSON: ders, çalışma görevi, program ve bağlantısız not eşlemesi", systemImage: "desktopcomputer")
                            Label("PDF, PencilKit ve ses ikili dosyaları JSON'a gömülmez", systemImage: "exclamationmark.triangle")
                                .foregroundStyle(PadTokens.warning)
                        }
                        TerminalCard("StudyPad yedeği") {
                            Text("Mevcut StudyPad kayıtlarınızı JSON olarak Files'a kaydedin. Bu işlem belge/ses dosyalarını sessizce kopyalamaz.").foregroundStyle(PadTokens.phosphorDim)
                            Button { prepareExport() } label: { Label("Study Pack dışa aktar", systemImage: "square.and.arrow.up") }
                                .buttonStyle(.bordered).frame(minHeight: PadTokens.minimumTap)
                        }
                        if let result {
                            TerminalCard("Son işlem") { Label("\(result.inserted) eklendi • \(result.updated) güncellendi • \(result.skipped) atlandı", systemImage: "checkmark.circle.fill") }
                        }
                    }.padding(24)
                }
            }.terminalPage().navigationTitle("Yerel aktarım")
                .fileImporter(isPresented: $importing, allowedContentTypes: [.json], allowsMultipleSelection: false) { handleSelection($0) }
                .sheet(isPresented: Binding(get: { preview != nil }, set: { if !$0 { preview = nil; prepared = nil } })) { if let preview { previewSheet(preview) } }
                .fileExporter(isPresented: $exporting, document: exportDocument, contentType: .json, defaultFilename: "NEXUS-StudyPad-Transfer-v1.json") { outcome in if case .failure(let issue) = outcome { error = issue.localizedDescription } }
                .alert("Aktarım hatası", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("Tamam") { error = nil } } message: { Text(error ?? "") }
        }
    }

    private func previewSheet(_ value: TransferPreview) -> some View {
        NavigationStack {
            Form {
                Section("Kaynak") { Text(value.source == .studyPadV1 ? "StudyPadTransfer v1" : "NEXUS Mac JSON") }
                Section("Önizleme") {
                    count("Ders", value.courseCount); count("Haftalık program", value.scheduleCount); count("Oturum", value.lectureCount); count("Metin notu", value.noteCount); count("Görev", value.taskCount)
                }
                if value.duplicateCount > 0 {
                    Section("Aynı kimlikli kayıtlar: \(value.duplicateCount)") {
                        Picker("Politika", selection: $policy) { ForEach(TransferDuplicatePolicy.allCases) { Text($0.title).tag($0) } }
                        Text(policy == .skip ? "Mevcut kayıt korunur; gelen eş kayıt yazılmaz." : "Yalnız aynı UUID'li kayıt alanları güncellenir. Kayıtlar topluca silinmez.").font(.caption)
                    }
                }
                if !value.warnings.isEmpty { Section("Sınırlar") { ForEach(value.warnings, id: \.self) { Label($0, systemImage: "info.circle") } } }
                Section { Text("Onay, doğrulanmış kayıtları tek ModelContext kaydıyla birleştirir. Replace veya toplu silme yapılmaz.").font(.caption).foregroundStyle(.secondary) }
            }.navigationTitle("İçe aktarma önizlemesi")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { preview = nil; prepared = nil } }
                    ToolbarItem(placement: .confirmationAction) { Button("Onayla ve içe aktar") { confirmImport() }.fontWeight(.bold) }
                }
        }.tint(PadTokens.phosphor)
    }
    private func count(_ label: String, _ value: Int) -> some View { HStack { Text(label); Spacer(); Text("\(value)").font(.body.monospaced().bold()) } }

    private func handleSelection(_ outcome: Result<[URL], Error>) {
        do {
            let url = try outcome.get().first ?? { throw StudyPadTransferError.unreadable }()
            let scoped = url.startAccessingSecurityScopedResource(); defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url, options: [.mappedIfSafe])
            let prepared = try StudyPadTransferService.prepare(data: data)
            self.prepared = prepared; preview = try StudyPadTransferService.preview(prepared, context: context); result = nil
        } catch { self.error = error.localizedDescription }
    }
    private func confirmImport() {
        guard let prepared else { return }
        do { result = try StudyPadTransferService.importPack(prepared, policy: policy, context: context); preview = nil; self.prepared = nil }
        catch { self.error = error.localizedDescription }
    }
    private func prepareExport() {
        do { exportDocument = TransferJSONDocument(data: try StudyPadTransferService.encoder().encode(StudyPadTransferService.export(context: context))); exporting = true }
        catch { self.error = error.localizedDescription }
    }
}
