import SwiftUI
import PDFKit
import Vision
import VisionKit
import CryptoKit

struct ImportDraft: Identifiable, Sendable {
    let id = UUID()
    let pdf: Data
    let digest: String
    let text: String
    let findings: [Finding]
    let warnings: [String]
}
enum DocumentService {
    static let maxBytes = 25 * 1024 * 1024
    static func load(_ url: URL) throws -> Data {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= maxBytes else { throw AppError.message("Bitte eine Datei unter 25 MB auswählen.") }
        return try Data(contentsOf: url, options: .mappedIfSafe)
    }
    static func process(_ data: Data) throws -> ImportDraft {
        guard data.count <= maxBytes else { throw AppError.message("Bitte eine Datei unter 25 MB auswählen.") }
        let document: PDFDocument
        if let pdf = PDFDocument(data: data) { document = pdf }
        else if let image = UIImage(data: data), let page = PDFPage(image: image) {
            document = PDFDocument(); document.insert(page, at: 0)
        } else { throw AppError.message("Diese Datei lässt sich nicht als PDF oder Bild öffnen.") }
        guard !document.isLocked else { throw AppError.message("Bitte das PDF zuerst ohne Passwortschutz bereitstellen.") }
        guard document.pageCount > 0, document.pageCount <= 30 else { throw AppError.message("Bitte 1 bis 30 Seiten pro Bericht importieren.") }
        var texts: [String] = []; var warnings: [String] = []
        for index in 0..<document.pageCount {
            try Task.checkCancellation()
            guard let page = document.page(at: index) else { throw AppError.message("Eine PDF-Seite konnte nicht geöffnet werden.") }
            let embedded = page.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let text: String
            if !embedded.isEmpty { text = embedded }
            else {
                text = try autoreleasepool {
                    let image = page.thumbnail(of: CGSize(width: 1800, height: 2400), for: .mediaBox)
                    guard let cgImage = image.cgImage else { throw AppError.message("Seite konnte nicht gerendert werden.") }
                    let request = VNRecognizeTextRequest()
                    request.recognitionLevel = .accurate
                    request.recognitionLanguages = ["de-DE", "en-US"]
                    request.usesLanguageCorrection = true
                    try VNImageRequestHandler(cgImage: cgImage).perform([request])
                    return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
                }
            }
            if text.isEmpty { warnings.append("Seite \(index + 1): Kein Text erkannt. Bitte im Original prüfen.") }
            texts.append("Seite \(index + 1)\n\(text)")
        }
        guard let pdfData = document.dataRepresentation() else { throw AppError.message("Das PDF konnte nicht gespeichert werden.") }
        let text = texts.joined(separator: "\n\n")
        return ImportDraft(pdf: pdfData, digest: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(), text: text, findings: ReportParser.findings(in: text), warnings: warnings)
    }
}
struct PDFPreview: UIViewRepresentable {
    let data: Data
    func makeUIView(context: Context) -> PDFView {
        let view = PDFView(); view.autoScales = true; view.displayMode = .singlePageContinuous
        view.document = PDFDocument(data: data); return view
    }
    func updateUIView(_ uiView: PDFView, context: Context) {}
}
struct DocumentScanner: UIViewControllerRepresentable {
    var finish: (Result<Data?, Error>) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(finish: finish) }
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let camera = VNDocumentCameraViewController(); camera.delegate = context.coordinator; return camera
    }
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}
    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let finish: (Result<Data?, Error>) -> Void
        init(finish: @escaping (Result<Data?, Error>) -> Void) { self.finish = finish }
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) { finish(.success(nil)) }
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) { finish(.failure(error)) }
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            guard scan.pageCount <= 30 else { finish(.failure(AppError.message("Bitte höchstens 30 Seiten scannen."))); return }
            let pdf = PDFDocument()
            for index in 0..<scan.pageCount {
                guard let page = PDFPage(image: scan.imageOfPage(at: index)) else { finish(.failure(AppError.message("Eine gescannte Seite konnte nicht verarbeitet werden."))); return }
                pdf.insert(page, at: index)
            }
            guard let data = pdf.dataRepresentation() else { finish(.failure(AppError.message("Scan konnte nicht gespeichert werden."))); return }
            finish(.success(data))
        }
    }
}
