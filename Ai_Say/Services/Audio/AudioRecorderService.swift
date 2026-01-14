// Services/Audio/AudioRecorderService.swift
import Foundation
import AVFoundation
import Combine

@MainActor
final class AudioRecorderService: ObservableObject {
    @Published var isRecording: Bool = false
    @Published var duration: TimeInterval = 0
    @Published var lastFileURL: URL?

    private var recorder: AVAudioRecorder?
    private var timer: Timer?

    func requestPermission() async -> Bool {
        if #available(iOS 17.0, *) {
            return await withCheckedContinuation { cont in
                AVAudioApplication.requestRecordPermission { granted in
                    cont.resume(returning: granted)
                }
            }
        } else {
            return await withCheckedContinuation { cont in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    cont.resume(returning: granted)
                }
            }
        }
    }

    func start() throws {
        let session = AVAudioSession.sharedInstance()

        // iOS 26：allowBluetoothHFP（替代 allowBluetooth）
        try session.setCategory(
            .playAndRecord,
            mode: .spokenAudio,
            options: [.defaultToSpeaker, .allowBluetoothHFP]
        )
        try session.setActive(true)

        let filename = "rec-\(Int(Date().timeIntervalSince1970)).m4a"
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder?.prepareToRecord()
        recorder?.record()

        isRecording = true
        duration = 0
        lastFileURL = url

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.duration += 0.1
            }
        }
    }

    func stop() {
        recorder?.stop()
        recorder = nil

        timer?.invalidate()
        timer = nil

        isRecording = false
    }
}