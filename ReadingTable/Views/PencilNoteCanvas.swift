import PencilKit
import SwiftUI
import UIKit

/// Square handwriting canvas. Coordinates stay in a fixed 260pt box so the
/// ink on the table matches what you wrote in the editor.
struct PencilNoteCanvas: UIViewRepresentable {
    static let canvasSize = CGSize(width: 260, height: 260)
    static let bounds = CGRect(origin: .zero, size: canvasSize)

    @Binding var drawing: PKDrawing
    var paperColor: UIColor

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.delegate = context.coordinator
        canvas.drawing = drawing
        canvas.backgroundColor = paperColor
        canvas.isOpaque = true
        canvas.drawingPolicy = .anyInput
        canvas.overrideUserInterfaceStyle = .light
        canvas.tool = PKInkingTool(.pen, color: UIColor(white: 0.14, alpha: 1), width: 7)
        canvas.minimumZoomScale = 1
        canvas.maximumZoomScale = 1
        canvas.isScrollEnabled = false
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        context.coordinator.parent = self
        canvas.backgroundColor = paperColor
        if canvas.drawing != drawing {
            canvas.drawing = drawing
        }
        guard canvas.window != nil else { return }
        let picker = context.coordinator.toolPicker
        picker.setVisible(true, forFirstResponder: canvas)
        picker.addObserver(canvas)
        canvas.becomeFirstResponder()
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: PencilNoteCanvas
        let toolPicker = PKToolPicker()

        init(_ parent: PencilNoteCanvas) {
            self.parent = parent
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.drawing = canvasView.drawing
        }
    }
}
