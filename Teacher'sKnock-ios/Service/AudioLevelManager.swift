import Foundation
import AVFoundation
import Combine

class AudioLevelManager: NSObject, ObservableObject {
    @Published var audioLevel: Float = 0.0
    @Published var isRecording = false
    @Published var isSpeaking = false // 임계값 넘었는지 여부
    
    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private let threshold: Float = -30.0 // 임계값 (dB)
    
    override init() {
        super.init()
    }
    
    func requestPermission(completion: @escaping (Bool) -> Void) {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }
    
    func startMonitoring() {
        // 이미 녹음 중이면 리턴
        guard !isRecording else { return }
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true)
            
            let url = URL(fileURLWithPath: "/dev/null")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatAppleLossless),
                AVSampleRateKey: 44100.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.min.rawValue
            ]
            
            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.isMeteringEnabled = true
            recorder?.record()
            
            isRecording = true
            startTimer()
            
        } catch {
            print("Failed to start audio monitoring: \(error)")
            stopMonitoring()
        }
    }
    
    func stopMonitoring() {
        recorder?.stop()
        recorder = nil
        isRecording = false
        stopTimer()
        audioLevel = 0.0
        isSpeaking = false
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let recorder = self.recorder else { return }
            recorder.updateMeters()
            
            // -160 dB ~ 0 dB
            let power = recorder.averagePower(forChannel: 0)
            self.audioLevel = power
            
            // 임계값 체크
            let wasSpeaking = self.isSpeaking
            self.isSpeaking = power > self.threshold
            
            // 상태 변화 디버깅 (필요 시)
            // if wasSpeaking != self.isSpeaking { print("Speaking state changed: \(self.isSpeaking)") }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
