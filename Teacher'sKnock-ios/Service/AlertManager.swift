import Foundation
import SwiftUI
import Combine
import FirebaseFirestore
import FirebaseAuth

class AlertManager: ObservableObject {
    @Published var showToast: Bool = false
    @Published var toastMessage: String = ""
    @Published var toastIcon: String = "bell.fill"
    
    private var db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    // 알림 리스닝 시작
    func startListening() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        // 중복 방지
        if listener != nil { return }
        
        print("🔔 AlertManager: 리스닝 시작 (\(uid))")
        
        listener = db.collection("users").document(uid).collection("alerts")
            .order(by: "timestamp", descending: false) // 오래된 것부터 처리
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                guard let documents = snapshot?.documents else { return }
                
                for doc in documents {
                    let data = doc.data()
                    let type = data["type"] as? String ?? ""
                    let fromNickname = data["fromNickname"] as? String ?? "누군가"
                    let toNickname = data["toNickname"] as? String ?? "회원"
                    
                    if type == "knock" {
                        // ✨ [Updated] "(타 맴버)님이 (나)님을 노크했어요!!"
                        self.triggerToast(message: "\(fromNickname)님이 \(toNickname)님을 노크했어요!!", icon: "hand.wave.fill")
                    } else if type == "delegate" {
                        // ✨ [New] 방장 위임 알림
                        let groupName = data["groupName"] as? String ?? "스터디"
                        self.triggerToast(message: "'\(groupName)' 스터디의 방장이 되었습니다!", icon: "star.circle.fill")
                    }
                    
                    // 처리 후 삭제
                    self.db.collection("users").document(uid).collection("alerts").document(doc.documentID).delete()
                }
            }
    }
    
    func stopListening() {
        listener?.remove()
        listener = nil
    }
    
    private func triggerToast(message: String, icon: String) {
        // 진동 피드백
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        DispatchQueue.main.async {
            self.toastMessage = message
            self.toastIcon = icon
            withAnimation {
                self.showToast = true
            }
            
            // 3초 후 숨김
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    self.showToast = false
                }
            }
        }
    }
}
