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
    
    static func dismantleNSView(_ nsView: PDFView, coordinator: Coordinator) {
        coordinator.stopTimer()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    @MainActor
    class Coordinator {
        private var timer: Timer?
        private var currentIndex = 0
        private var pageCount = 0
        private var loop = false
        private weak var pdfView: PDFView?
        private var document: PDFDocument?
        
        func startTimer(pdfView: PDFView, document: PDFDocument, interval: TimeInterval, loop: Bool) {
            timer?.invalidate()
            currentIndex = 0
            self.pdfView = pdfView
            self.document = document
            self.pageCount = document.pageCount
            self.loop = loop
            
            timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.advancePage()
                }
            }
        }
        
        private func advancePage() {
            currentIndex += 1
            
            if currentIndex >= pageCount {
                if loop {
                    currentIndex = 0
                } else {
                    timer?.invalidate()
                    return
                }
            }
            
            if let page = document?.page(at: currentIndex) {
                pdfView?.go(to: page)
            }
        }
        
        func stopTimer() {
            timer?.invalidate()
            timer = nil
        }
        
        deinit {
            // Timer is invalidated in stopTimer() called from updateNSView or view teardown
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
