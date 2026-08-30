import SwiftUI
import PDFKit

struct PDFKitView: UIViewRepresentable {
    let url: URL
    @Binding var pageIndex: Int
    @Binding var pageCount: Int

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true; view.displayMode = .singlePageContinuous; view.displayDirection = .vertical
        view.document = PDFDocument(url: url)
        pageCount = view.document?.pageCount ?? 0
        NotificationCenter.default.addObserver(context.coordinator, selector: #selector(Coordinator.pageChanged(_:)), name: .PDFViewPageChanged, object: view)
        return view
    }
    func updateUIView(_ view: PDFView, context: Context) {
        guard let document = view.document, pageIndex >= 0, pageIndex < document.pageCount,
              view.currentPage != document.page(at: pageIndex), let page = document.page(at: pageIndex) else { return }
        view.go(to: page)
    }
    static func dismantleUIView(_ uiView: PDFView, coordinator: Coordinator) { NotificationCenter.default.removeObserver(coordinator) }
    final class Coordinator: NSObject {
        var parent: PDFKitView
        init(parent: PDFKitView) { self.parent = parent }
        @objc func pageChanged(_ note: Notification) {
            guard let view = note.object as? PDFView, let page = view.currentPage, let document = view.document else { return }
            parent.pageIndex = document.index(for: page)
        }
    }
}

struct PDFInkEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let documentID: UUID
    let pageIndex: Int
    let existingLayer: PDFInkLayer?
    @State private var drawingData: Data

    init(documentID: UUID, pageIndex: Int, existingLayer: PDFInkLayer?) {
        self.documentID = documentID; self.pageIndex = pageIndex; self.existingLayer = existingLayer
        _drawingData = State(initialValue: existingLayer?.drawingData ?? Data())
    }
    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                Text("Bu çizim PDF dosyasını değiştirmez; seçili sayfaya bağlı yerel bir mürekkep katmanı olarak saklanır.")
                    .font(.caption).foregroundStyle(PadTokens.phosphorDim).padding(.horizontal)
                PencilCanvasView(drawingData: $drawingData).clipShape(RoundedRectangle(cornerRadius: 10)).padding()
            }.background(PadTokens.background).terminalPage().navigationTitle("Sayfa \(pageIndex + 1) çizimi")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Kaydet") { save() } }
                }
        }
    }
    private func save() {
        if let existingLayer { existingLayer.drawingData = drawingData; existingLayer.updatedAt = .now }
        else { context.insert(PDFInkLayer(documentID: documentID, pageIndex: pageIndex, drawingData: drawingData)) }
        try? context.save(); dismiss()
    }
}
