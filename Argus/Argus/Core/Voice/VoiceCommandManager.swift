import Speech
import AVFoundation

final class VoiceCommandManager {
    enum Command {
        case allow
        case deny
        case allowAll
    }

    var onCommand: ((Command) -> Void)?
    var isListening: Bool { audioEngine.isRunning }

    private let speechRecognizer: SFSpeechRecognizer?
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var enabled = false

    init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "tr-TR"))
            ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    func setEnabled(_ enabled: Bool) {
        self.enabled = enabled
        if enabled {
            requestPermission()
        } else {
            stopListening()
        }
    }

    func startListening() {
        guard enabled, !audioEngine.isRunning else { return }

        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            guard status == .authorized else { return }
            DispatchQueue.main.async {
                self?.beginRecognition()
            }
        }
    }

    func stopListening() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
    }

    private func requestPermission() {
        SFSpeechRecognizer.requestAuthorization { _ in }
    }

    private func beginRecognition() {
        guard let speechRecognizer, speechRecognizer.isAvailable else { return }

        // Cleanup previous
        recognitionTask?.cancel()
        recognitionRequest = nil

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true // Gizlilik — sunucuya gonderme
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            print("[Argus] Audio engine start failed: \(error)")
            return
        }

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self, let result else {
                if error != nil { self?.restartListening() }
                return
            }

            let text = result.bestTranscription.formattedString.lowercased()

            // Komut algılama
            if text.contains("izin ver") || text.contains("allow") || text.contains("yes") {
                self.onCommand?(.allow)
                self.restartListening()
            } else if text.contains("reddet") || text.contains("deny") || text.contains("no") {
                self.onCommand?(.deny)
                self.restartListening()
            } else if text.contains("hepsine") || text.contains("allow all") {
                self.onCommand?(.allowAll)
                self.restartListening()
            }
        }
    }

    private func restartListening() {
        stopListening()
        // Kısa bekleme sonrası tekrar başla
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self, self.enabled else { return }
            self.startListening()
        }
    }
}
