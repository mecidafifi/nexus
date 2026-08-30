import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct DocumentListView: View {
    @Query(sort: \StudyDocument.importedAt, order: .reverse) private var documents: [StudyDocument]
    @Query(sort: \Course.name) private var courses: [Course]
    @Query(sort: \Lecture.date, order: .reverse) private var lectures: [Lecture]
    @Query private var inkLayers: [PDFInkLayer]
    @Environment(\.modelContext) private var context
    @State private var importing = false
    @State private var importedURL: URL?
    @State private var pendingTitle = ""
    @State private var pendingCourseID: UUID?
    @State private var pendingLectureID: UUID?
    @State private var confirmingImport = false
    @State private var deleting: StudyDocument?
    @State private var error: String?
    @State private var search = ""
    @State private var renaming: StudyDocument?
    @State private var renameTitle = ""

    private var filtered: [StudyDocument] { search.isEmpty ? documents : documents.filter { $0.title.localizedCaseInsensitiveContains(search) } }

    var body: some View {
        NavigationStack {
            ZStack {
                TerminalBackground()
                if filtered.isEmpty { TerminalEmptyState(icon: "doc.richtext", title: "PDF yok", message: search.isEmpty ? "Dosyalar uygulamaya yalnız siz seçtikten sonra kopyalanır." : "Aramayla eşleşen PDF yok.") }
                else {
                    List(filtered) { document in
                        NavigationLink { DocumentViewerView(document: document) } label: {
                            Label { VStack(alignment: .leading) { Text(document.title).font(.headline); Text(document.importedAt, format: .dateTime.day().month().year()).font(.caption).foregroundStyle(PadTokens.phosphorDim) } } icon: { Image(systemName: "doc.richtext") }
                                .padding(.vertical, 7)
                        }.swipeActions {
                            Button(role: .destructive) { deleting = document } label: { Label("Sil", systemImage: "trash") }
                            Button { renaming = document; renameTitle = document.title } label: { Label("Yeniden adlandır", systemImage: "pencil") }
                        }
                    }.scrollContentBackground(.hidden)
                }
            }.terminalPage().navigationTitle("Belgeler")
                .searchable(text: $search, prompt: "PDF ara")
                .toolbar { Button { importing = true } label: { Label("PDF içe aktar", systemImage: "square.and.arrow.down") } }
                .fileImporter(isPresented: $importing, allowedContentTypes: [.pdf], allowsMultipleSelection: false) { result in
                    switch result {
                    case .success(let urls): guard let url = urls.first else { return }; importedURL = url; pendingTitle = url.deletingPathExtension().lastPathComponent; pendingCourseID = nil; pendingLectureID = nil; confirmingImport = true
                    case .failure(let issue): error = issue.localizedDescription
                    }
                }
                .sheet(isPresented: $confirmingImport) { importSheet }
                .alert("PDF ve çizimleri silinsin mi?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
                    Button("Vazgeç", role: .cancel) { deleting = nil }
                    Button("Sil", role: .destructive) { if let deleting { delete(deleting) }; deleting = nil }
                } message: { Text("Uygulama alanındaki PDF kopyası ve ona bağlı yerel çizimler kalıcı olarak silinir.") }
                .alert("İçe aktarma hatası", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("Tamam") { error = nil } } message: { Text(error ?? "") }
                .alert("PDF adını değiştir", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
                    TextField("Belge başlığı", text: $renameTitle)
                    Button("Vazgeç", role: .cancel) { renaming = nil }
                    Button("Kaydet") { if let renaming, !renameTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { renaming.title = renameTitle.trimmingCharacters(in: .whitespacesAndNewlines); renaming.updatedAt = .now; try? context.save() }; self.renaming = nil }
                } message: { Text("Yalnız görünen başlık değişir; yerel PDF dosyası korunur.") }
        }
    }

    private var importSheet: some View {
        NavigationStack {
            Form {
                TextField("Belge başlığı", text: $pendingTitle)
                Picker("Ders (isteğe bağlı)", selection: $pendingCourseID) { Text("Atanmamış").tag(UUID?.none); ForEach(courses) { Text($0.name).tag(Optional($0.id)) } }
                Picker("Oturum (isteğe bağlı)", selection: $pendingLectureID) { Text("Atanmamış").tag(UUID?.none); ForEach(lectures.filter { pendingCourseID == nil || $0.courseID == pendingCourseID }) { Text($0.title).tag(Optional($0.id)) } }
                Text("Seçtiğiniz PDF, yalnız bu uygulamanın yerel alanına kopyalanır.").font(.caption).foregroundStyle(.secondary)
            }.navigationTitle("PDF içe aktar")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { confirmingImport = false } }; ToolbarItem(placement: .confirmationAction) { Button("İçe aktar") { performImport() }.disabled(pendingTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) } }
        }
    }
    private func performImport() {
        guard let importedURL else { return }
        do { let service = try DocumentImportService(); let file = try service.importPDF(from: importedURL); context.insert(StudyDocument(courseID: pendingCourseID, lectureID: pendingLectureID, title: pendingTitle.trimmingCharacters(in: .whitespacesAndNewlines), storedFileName: file.storedFileName)); try context.save(); confirmingImport = false; self.importedURL = nil }
        catch { self.error = error.localizedDescription; confirmingImport = false }
    }
    private func delete(_ document: StudyDocument) {
        if let service = try? DocumentImportService() { try? service.delete(storedFileName: document.storedFileName) }
        inkLayers.filter { $0.documentID == document.id }.forEach(context.delete)
        context.delete(document); try? context.save()
    }
}

struct DocumentViewerView: View {
    let document: StudyDocument
    @Query private var inkLayers: [PDFInkLayer]
    @State private var pageIndex = 0
    @State private var pageCount = 0
    @State private var showingInk = false
    @State private var error: String?
    private var fileURL: URL? { (try? DocumentImportService())?.url(for: document.storedFileName) }
    private var layer: PDFInkLayer? { inkLayers.first { $0.documentID == document.id && $0.pageIndex == pageIndex } }

    var body: some View {
        ZStack {
            TerminalBackground()
            if let fileURL, FileManager.default.fileExists(atPath: fileURL.path) {
                VStack(spacing: 0) {
                    HStack { Text("Sayfa \(pageIndex + 1) / \(max(pageCount, 1))"); Spacer(); if layer != nil { TerminalStatusBadge(text: "Çizim kayıtlı") }; Button { showingInk = true } label: { Label("Bu sayfaya çiz", systemImage: "pencil.tip.crop.circle") }.buttonStyle(.bordered) }.padding()
                    PDFKitView(url: fileURL, pageIndex: $pageIndex, pageCount: $pageCount).background(Color.white)
                }
            } else { TerminalErrorState(message: "Yerel PDF dosyası bulunamadı.") }
        }.terminalPage().navigationTitle(document.title)
            .sheet(isPresented: $showingInk) { PDFInkEditorView(documentID: document.id, pageIndex: pageIndex, existingLayer: layer) }
    }
}
