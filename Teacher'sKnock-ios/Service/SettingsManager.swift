import Foundation
import SwiftUI
import Combine
import FirebaseFirestore
import FirebaseAuth

class SettingsManager: ObservableObject {
    
    // ✨ [핵심 변경] SubjectName(Enum) -> StudySubject(Struct)로 변경
    @Published var favoriteSubjects: [StudySubject] = []
    
    private let db = Firestore.firestore()
    private let settingsCollectionName = "settings"
    private let favoriteSubjectsDocument = "favorite_subjects"
    
    init() {
        loadSubjects()
    }
    
    // ✨ 과목 추가 함수
    func addSubject(_ name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty { return }
        
        // 중복 체크
        if !favoriteSubjects.contains(where: { $0.name == trimmedName }) {
            let newSubject = StudySubject(name: trimmedName)
            favoriteSubjects.append(newSubject)
            
            if let uid = Auth.auth().currentUser?.uid {
                saveFavoriteSubjects(uid: uid, favoriteSubjects)
            } else {
                saveToLocal()
            }
        }
    }
    
    // ✨ 과목 삭제 함수
    func removeSubject(at offsets: IndexSet) {
        favoriteSubjects.remove(atOffsets: offsets)
        
        if let uid = Auth.auth().currentUser?.uid {
            saveFavoriteSubjects(uid: uid, favoriteSubjects)
        } else {
            saveToLocal()
        }
    }
    
    func reset() {
        self.favoriteSubjects = defaultSubjects()
    }
    
    // 서버에서 불러오기
    func fetchSettings(uid: String) {
        let docRef = db.collection("users").document(uid).collection(settingsCollectionName).document(favoriteSubjectsDocument)
        
        docRef.getDocument { [weak self] document, error in
            guard let self = self else { return }
            
            if let document = document, document.exists, let data = document.data() {
                if let subjectStrings = data["subjects"] as? [String] {
                    // 문자열 -> StudySubject 변환
                    let loadedSubjects = subjectStrings.map { StudySubject(name: $0) }
                    DispatchQueue.main.async {
                        self.favoriteSubjects = loadedSubjects
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.favoriteSubjects = self.defaultSubjects()
                    self.saveFavoriteSubjects(uid: uid, self.favoriteSubjects)
                }
            }
        }
    }
    
    // 서버 저장
    func saveFavoriteSubjects(uid: String, _ subjects: [StudySubject]) {
        self.favoriteSubjects = subjects
        let subjectStrings = subjects.map { $0.name }
        
        let dataToSave: [String: Any] = [
            "subjects": subjectStrings,
            "lastUpdated": Timestamp(date: Date())
        ]
        
        db.collection("users").document(uid).collection(settingsCollectionName).document(favoriteSubjectsDocument).setData(dataToSave)
    }
    
    // 로컬 저장 (비로그인용)
    private func saveToLocal() {
        let strings = favoriteSubjects.map { $0.name }
        UserDefaults.standard.set(strings, forKey: "localFavoriteSubjects")
    }
    
    private func loadSubjects() {
        if let strings = UserDefaults.standard.stringArray(forKey: "localFavoriteSubjects") {
            self.favoriteSubjects = strings.map { StudySubject(name: $0) }
        } else {
            self.favoriteSubjects = defaultSubjects()
        }
    }
    
    // 기본값 생성기
    private func defaultSubjects() -> [StudySubject] {
        return [
            StudySubject(name: "교육학"),
            StudySubject(name: "전공"),
            StudySubject(name: "한국사")
        ]
    }
}
