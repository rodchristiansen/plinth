@preconcurrency import PDFKit
import SwiftUI

// MARK: - Native PDF View

struct NativePDFView: NSViewRepresentable {
    let url: URL
    let interval: TimeInterval
    let loop: Bool
    
    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.displaysPageBreaks = false
        pdfView.backgroundColor = .black
        
        if let document = PDFDocument(url: url) {
            pdfView.document = document
            
            if interval > 0 {
                context.coordinator.startTimer(
                    pdfView: pdfView,
                    document: document,
                    interval: interval,
                    loop: loop
                )
            }
        }
        
        return pdfView
    }
    
    func updateNSView(_ nsView: PDFView, context: Context) {
        // URL changes not supported during display
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        private var timer: Timer?
        private var currentIndex = 0
        
        func startTimer(pdfView: PDFView, document: PDFDocument, interval: TimeInterval, loop: Bool) {
            timer?.invalidate()
            currentIndex = 0
            
            timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                
                self.currentIndex += 1
                
                if self.currentIndex >= document.pageCount {
                    if loop {
                        self.currentIndex = 0
                    } else {
                        self.timer?.invalidate()
                        return
                    }
                }
                
                if let page = document.page(at: self.currentIndex) {
                    DispatchQueue.main.async {
                        pdfView.go(to: page)
                    }
                }
            }
        }
        
        deinit {
            timer?.invalidate()
        }
    }
}

// MARK: - PDF Viewer View

struct PDFViewerView: View {
    let url: URL
    let slideshowInterval: Int
    let loop: Bool
    
    var body: some View {
        NativePDFView(
            url: url,
            interval: TimeInterval(slideshowInterval),
            loop: loop
        )
        .ignoresSafeArea()
    }
}

#Preview {
    PDFViewerView(
        url: URL(fileURLWithPath: "/Users/Shared/sample.pdf"),
        slideshowInterval: 5,
        loop: true
    )
}
