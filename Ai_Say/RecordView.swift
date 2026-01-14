import SwiftUI
import AVFoundation
import AVKit

struct RecordUploadView: View {
    @StateObject private var api = APIManager.shared
    @StateObject private var recorder = AudioRecorder()

    @State private var prompt = "Free Talk"
    @State private var player: AVPlayer?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    Text(api.serverMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Prompt").font(.headline)
                        TextField("可选：题目", text: $prompt)
                            .textFieldStyle(.roundedBorder)
                    }

                    HStack(spacing: 12) {
                        Button(recorder.isRecording ? "停止录音" : "开始录音") {
                            Task {
                                if recorder.isRecording {
                                    recorder.stop()
                                } else {
                                    let ok = await recorder.requestPermission()
                                    guard ok else { api.serverMessage = "❌ 无麦克风权限"; return }
                                    do { try recorder.start() }
                                    catch { api.serverMessage = "❌ 录音失败：\(error.localizedDescription)" }
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)

                        Button("上传并评分") {
                            guard let url = recorder.lastFileURL else {
                                api.serverMessage = "❌ 还没有录音文件"
                                return
                            }
                            api.uploadAudio(fileURL: url, prompt: prompt)
                        }
                        .buttonStyle(.bordered)
                        .disabled(recorder.isRecording || api.isLoading)
                    }

                    if let res = api.evalResult {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("评分结果").font(.headline)

                            HStack {
                                Text("Fluency \(Int(res.fluency))")
                                Spacer()
                                Text("Completeness \(Int(res.completeness))")
                                Spacer()
                                Text("Relevance \(Int(res.relevance))")
                            }
                            .font(.subheadline)

                            if let audioPath = res.audioUrl,
                               let url = api.fullAudioURL(from: audioPath) {
                                Button("播放刚上传的录音") {
                                    player = AVPlayer(url: url)
                                    player?.play()
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                        .padding()
                        .background(.secondary.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding()
            }
            .navigationTitle("录音上传")
        }
    }
}