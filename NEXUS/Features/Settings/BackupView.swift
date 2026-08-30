import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct BackupView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var exportDocument: JSONBackupDocument?
    @State private var exporting = false
    @State private var importing = false
    @State private var pendingBackup: NEXUSBackup?
    @State private var mode: BackupImportMode = .merge
    @State private var confirmReplace = false
    @State private var message: String?
    @State private var isError = false

    var body: some View {
        TerminalWindow { TerminalDialog(titleKey: "backup.title") {
            Text("backup.explanation").foregroundStyle(TerminalTokens.phosphorMuted)
            Picker("backup.importMode", selection: $mode) {
                Text("backup.merge").tag(BackupImportMode.merge)
                Text("backup.replace").tag(BackupImportMode.replace)
            }.pickerStyle(.segmented)
            HStack {
                Button { prepareExport() } label: { Label("backup.export", systemImage: "square.and.arrow.up") }.buttonStyle(TerminalButtonStyle())
                Button { importing = true } label: { Label("backup.import", systemImage: "square.and.arrow.down") }.buttonStyle(TerminalButtonStyle())
            }
            if let message { Label(message, systemImage: isError ? "xmark.octagon" : "checkmark.circle").foregroundStyle(isError ? TerminalTokens.error : TerminalTokens.success) }
            HStack { Spacer(); Button("action.done") { dismiss() }.buttonStyle(TerminalPrimaryButtonStyle()) }
        }.padding() }
        .frame(width: 580, height: 360)
        .fileExporter(isPresented: $exporting, document: exportDocument, contentType: .json, defaultFilename: "NEXUS-Backup") { result in
            if case .failure(let error) = result { setError(error) } else { setSuccess("backup.exported") }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in handleImport(result) }
        .confirmationDialog("backup.replace.confirmTitle", isPresented: $confirmReplace) {
            Button("backup.replace.confirm", role: .destructive) { applyPending() }
            Button("action.cancel", role: .cancel) { pendingBackup = nil }
        } message: { Text("backup.replace.confirmMessage") }
    }

    private func prepareExport() {
        do { exportDocument = JSONBackupDocument(data: try BackupService.encoded(BackupService.export(from: context))); exporting = true }
        catch { setError(error) }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let accessing = url.startAccessingSecurityScopedResource(); defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            pendingBackup = try BackupService.decoded(Data(contentsOf: url))
            if mode == .replace { confirmReplace = true } else { applyPending() }
        } catch { setError(error) }
    }

    private func applyPending() {
        guard let pendingBackup else { return }
        do { try BackupService.apply(pendingBackup, mode: mode, to: context); self.pendingBackup = nil; setSuccess("backup.imported") }
        catch { setError(error) }
    }

    private func setSuccess(_ key: String) { isError = false; message = String(localized: String.LocalizationValue(key)) }
    private func setError(_ error: Error) { isError = true; message = error.localizedDescription }
}
