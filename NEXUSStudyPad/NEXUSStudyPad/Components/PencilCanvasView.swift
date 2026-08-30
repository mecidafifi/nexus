import PencilKit
import SwiftUI

struct PencilCanvasView: UIViewRepresentable {
    @Binding var drawingData: Data
    var backgroundColor: UIColor = UIColor(PadTokens.background)

    func makeCoordinator() -> Coordinator { Coordinator(data: $drawingData) }
    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.delegate = context.coordinator
        canvas.drawingPolicy = .anyInput
        canvas.backgroundColor = backgroundColor
        canvas.isOpaque = true
        canvas.tool = PKInkingTool(.pen, color: UIColor(PadTokens.phosphor), width: 3)
        if let drawing = try? PKDrawing(data: drawingData) { canvas.drawing = drawing }
        context.coordinator.canvas = canvas
        return canvas
    }
    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        guard !context.coordinator.isWriting,
              let drawing = try? PKDrawing(data: drawingData),
              drawing.dataRepresentation() != canvas.drawing.dataRepresentation() else { return }
        canvas.drawing = drawing
    }
    final class Coordinator: NSObject, PKCanvasViewDelegate {
        @Binding var data: Data
        weak var canvas: PKCanvasView?
        var isWriting = false
        init(data: Binding<Data>) { _data = data }
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            isWriting = true; data = canvasView.drawing.dataRepresentation(); isWriting = false
        }
    }
}
