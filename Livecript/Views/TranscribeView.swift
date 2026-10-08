import SwiftUI
import UIKit
struct TranscribeView: View {
    @Bindable var session: TranscriptionSession
    let store: TranscriptStore
    let preferences: AppPreferences
    let service: AppleSpeechService
    @State private var copied = false
    @State private var confirmDiscard = false
    @State private var actionError: String?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Label("Sur cet appareil", systemImage: "lock.shield")
                        .font(.caption).foregroundStyle(.secondary)
                    if session.displayText.isEmpty {
                        Text("Parlez.\nLe texte suivra.").font(.largeTitle).foregroundStyle(.secondary).padding(.top, 48)
                    } else {
                        (Text(session.finalText) + Text(session.provisionalText.isEmpty ? "" : " " + session.provisionalText).foregroundColor(.secondary))
                            .font(.title2).lineSpacing(8).textSelection(.enabled)
                    }
                    if let message = session.errorMessage {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(message).font(.callout).foregroundStyle(.red)
                            Button("Réglages de l’iPhone") { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }
                        }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(24)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 12) {
                    AudioLevelView(meter: session.meter, active: session.state == .recording)
                    if session.state == .preparing {
                        ProgressView(service.resourceMessage)
                        if let progress = service.downloadProgress { ProgressView(value: progress).padding(.horizontal, 32) }
                        Button("Annuler") { Task { await session.pause() } }
                    } else if session.state == .finalizing {
                        ProgressView("Finalisation…")
                    } else {
                        HStack(spacing: 16) {
                            if session.state == .recording {
                                Button("Pause", systemImage: "pause.fill") { Task { await session.pause() } }.buttonStyle(.glassProminent)
                                Button("Terminer", systemImage: "stop.fill") { Task { await session.finish() } }.buttonStyle(.glass)
                            } else if session.state == .paused || session.state == .failed {
                                Button("Reprendre", systemImage: "mic.fill") { Task { await session.resume() } }.buttonStyle(.glassProminent)
                                Button("Terminer") { Task { await session.finish() } }.buttonStyle(.glass)
                            } else if session.finalText.isEmpty {
                                Button("Démarrer", systemImage: "mic.fill") { start() }.buttonStyle(.glassProminent)
                            } else {
                                Button(session.saved ? "Enregistré" : "Enregistrer", systemImage: session.saved ? "checkmark" : "tray.and.arrow.down") { Task { do { _ = try await session.save() } catch { actionError = error.localizedDescription } } }
                                    .buttonStyle(.glassProminent).disabled(session.saved)
                                Button("Nouveau", systemImage: "plus") {
                                    if session.saved { reset() } else { confirmDiscard = true }
                                }.buttonStyle(.glass)
                            }
                        }.controlSize(.large)
                    }
                    if !session.displayText.isEmpty {
                        HStack(spacing: 24) {
                            Button(copied ? "Copié" : "Copier", systemImage: copied ? "checkmark" : "doc.on.doc") {
                                UIPasteboard.general.string = session.displayText; copied = true
                                Task { try? await Task.sleep(for: .seconds(2)); copied = false }
                            }
                            ShareLink(item: session.displayText) { Label("Partager", systemImage: "square.and.arrow.up") }
                        }.font(.subheadline).padding(.vertical, 8)
                    }
                }.frame(maxWidth: .infinity).padding(.horizontal, 16).padding(.bottom, 16)
                    .background(.regularMaterial)
            }
            .navigationTitle("Transcrire")
            .confirmationDialog("Abandonner cette transcription ?", isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button("Enregistrer et continuer") { Task { do { _ = try await session.save(); try await session.discard() } catch { actionError = error.localizedDescription } } }
                Button("Abandonner", role: .destructive) { reset() }
            }
            .alert("Action impossible", isPresented: Binding(get: { actionError != nil }, set: { if !$0 { actionError = nil } })) { Button("OK", role: .cancel) {} } message: { Text(actionError ?? "") }
        }
    }
    private func start() {
        Task {
            do { await session.start(configuration: .init(localeIdentifier: preferences.localeIdentifier, mode: preferences.mode, vocabulary: try await store.vocabulary().map(\.phrase))) }
            catch { actionError = error.localizedDescription }
        }
    }
    private func reset() { Task { do { try await session.discard() } catch { actionError = error.localizedDescription } } }
}
