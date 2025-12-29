import Foundation
import SwiftUI
import Combine
import FirebaseFirestore
import FirebaseAuth

class SettingsManager: ObservableObject {
    
    // 1. 선호 과목
    @Published var favoriteSubjects: [StudySubject] = []
    
    // 2. 맞춤 정보
    @Published var myUniversity: University? {
        didSet { saveUserSetting(value: myUniversity, key: "myUniversity", field: "university") }
    }
    @Published var targetOffice: OfficeOfEducation? {
        didSet { saveUserSetting(value: targetOffice, key: "targetOffice", field: "targetOffice") }
    }
    
    private let db = Firestore.firestore()
    private let settingsCollectionName = "settings"
    private let favoriteSubjectsDocument = "favorite_subjects"
    
    init() { }
    
    // MARK: - 사용자별 데이터 로드
    func loadSettings(for uid: String) {
        print("SettingsManager: \(uid)의 설정을 불러옵니다.")
        fetchFavoriteSubjects(uid: uid)
        
        if let data = UserDefaults.standard.data(forKey: "myUniversity_\(uid)"),
           let univ = try? JSONDecoder().decode(University.self, from: data) {
            self.myUniversity = univ
        }
        if let data = UserDefaults.standard.data(forKey: "targetOffice_\(uid)"),
           let office = try? JSONDecoder().decode(OfficeOfEducation.self, from: data) {
            self.targetOffice = office
        }
    }
    
    // ✨ [핵심 수정] 이 함수가 없어서 오류가 났던 것입니다!
    // 로그아웃 시 메모리 데이터를 초기화하는 함수
    func reset() {
        print("SettingsManager: 데이터 메모리 초기화")
        self.favoriteSubjects = []
        self.myUniversity = nil
        self.targetOffice = nil
    }
    
    // MARK: - 과목 관리 함수
    func addSubject(_ name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty { return }
        
        if !favoriteSubjects.contains(where: { $0.name == trimmedName }) {
            let newSubject = StudySubject(name: trimmedName)
            favoriteSubjects.append(newSubject)
            if let uid = Auth.auth().currentUser?.uid {
                saveFavoriteSubjects(uid: uid, favoriteSubjects)
            }
        }
    }
    
    func removeSubject(at offsets: IndexSet) {
        favoriteSubjects.remove(atOffsets: offsets)
        if let uid = Auth.auth().currentUser?.uid {
            saveFavoriteSubjects(uid: uid, favoriteSubjects)
        }
    }
    
    private func fetchFavoriteSubjects(uid: String) {
            let docRef = db.collection("users").document(uid).collection(settingsCollectionName).document(favoriteSubjectsDocument)
            
            docRef.getDocument { [weak self] document, error in
                guard let self = self else { return }
                
                // ✨ [수정 포인트] '!subjectStrings.isEmpty' 조건을 추가했습니다.
                // 문서가 있고(exists) + 과목 리스트가 비어있지 않아야만 가져옵니다.
                if let document = document, document.exists, let data = document.data(),
                   let subjectStrings = data["subjects"] as? [String], !subjectStrings.isEmpty {
                    
                    // 기존에 저장된 과목이 있으면 그것을 로드
                    let loadedSubjects = subjectStrings.map { StudySubject(name: $0) }
                    DispatchQueue.main.async { self.favoriteSubjects = loadedSubjects }
                    
                } else {
                    // ✨ 문서가 없거나(신규), 문서가 있는데 과목이 텅 비어있으면(기존)
                    // -> 13개 기본 과목을 강제로 주입합니다!
                    print("⚠️ 저장된 과목이 없어서 기본 13과목을 세팅합니다.")
                    DispatchQueue.main.async {
                        self.favoriteSubjects = self.defaultSubjects()
                        self.saveFavoriteSubjects(uid: uid, self.favoriteSubjects)
                    }
                }
            }
        }
    
    func saveFavoriteSubjects(uid: String, _ subjects: [StudySubject]) {
        self.favoriteSubjects = subjects
        let subjectStrings = subjects.map { $0.name }
        let dataToSave: [String: Any] = ["subjects": subjectStrings, "lastUpdated": Timestamp(date: Date())]
        db.collection("users").document(uid).collection(settingsCollectionName).document(favoriteSubjectsDocument).setData(dataToSave)
    }
    
    // 기본 과목 (13과목 리스트 참조)
    private func defaultSubjects() -> [StudySubject] {
        return SubjectName.defaultList.map { StudySubject(name: $0) }
    }
    
    private func saveUserSetting<T: Codable>(value: T?, key: String, field: String) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let uniqueKey = "\(key)_\(uid)"
        if let value = value, let encoded = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(encoded, forKey: uniqueKey)
        } else {
            UserDefaults.standard.removeObject(forKey: uniqueKey)
        }
        
        // Firestore 업데이트 로직
        var valueToSave: Any? = nil
        if let univ = value as? University { valueToSave = univ.name }
        if let office = value as? OfficeOfEducation { valueToSave = office.rawValue }
        if let finalValue = valueToSave {
            db.collection("users").document(uid).updateData([field: finalValue])
        }
    }
}
