import Foundation
import SwiftUI
import Combine
import FirebaseFirestore
import FirebaseAuth

class SettingsManager: ObservableObject {
    
    // 1. 선호 과목 (StudySubject 구조체 사용)
    @Published var favoriteSubjects: [StudySubject] = []
    
    // 2. 맞춤 정보 (대학교, 교육청) - 변경 시 로컬에 자동 저장
    @Published var myUniversity: University? {
        didSet { saveNoticeSettings() }
    }
    @Published var targetOffice: OfficeOfEducation? {
        didSet { saveNoticeSettings() }
    }
    
    private let db = Firestore.firestore()
    private let settingsCollectionName = "settings"
    private let favoriteSubjectsDocument = "favorite_subjects"
    
    init() {
        loadSettings()
    }
    
    // MARK: - 대학교 자동 설정 (로그인 연동용)
    
    // ✨ [추가됨] 이름 문자열로 대학교 정보를 찾아 자동 세팅하는 함수
    func setUniversity(fromName name: String) {
        // NoticeData.swift에 있는 전체 리스트에서 검색
        if let foundUniv = University.find(byName: name) {
            DispatchQueue.main.async {
                self.myUniversity = foundUniv
                print("SettingsManager: 대학교 자동 설정 완료 (\(name))")
            }
        } else {
            print("SettingsManager: 해당 이름의 대학교 정보를 찾을 수 없음 (\(name))")
        }
    }
    
    // MARK: - 과목 관리 로직
    
    func addSubject(_ name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty { return }
        
        // 중복 체크
        if !favoriteSubjects.contains(where: { $0.name == trimmedName }) {
            let newSubject = StudySubject(name: trimmedName)
            favoriteSubjects.append(newSubject)
            
            // 로그인 상태면 서버 동기화, 아니면 로컬 저장
            if let uid = Auth.auth().currentUser?.uid {
                saveFavoriteSubjects(uid: uid, favoriteSubjects)
            } else {
                saveSubjectsToLocal()
            }
        }
    }
    
    func removeSubject(at offsets: IndexSet) {
        favoriteSubjects.remove(atOffsets: offsets)
        
        if let uid = Auth.auth().currentUser?.uid {
            saveFavoriteSubjects(uid: uid, favoriteSubjects)
        } else {
            saveSubjectsToLocal()
        }
    }
    
    // 로그아웃 시 데이터 초기화
    func reset() {
        self.favoriteSubjects = defaultSubjects()
        self.myUniversity = nil
        self.targetOffice = nil
        
        UserDefaults.standard.removeObject(forKey: "localFavoriteSubjects")
        UserDefaults.standard.removeObject(forKey: "myUniversity")
        UserDefaults.standard.removeObject(forKey: "targetOffice")
    }
    
    // MARK: - 데이터 로드 및 저장 (로컬)
    
    private func loadSettings() {
        // 1. 과목 로드
        if let strings = UserDefaults.standard.stringArray(forKey: "localFavoriteSubjects") {
            self.favoriteSubjects = strings.map { StudySubject(name: $0) }
        } else {
            self.favoriteSubjects = defaultSubjects()
        }
        
        // 2. 대학교 정보 로드
        if let univData = UserDefaults.standard.data(forKey: "myUniversity"),
           let univ = try? JSONDecoder().decode(University.self, from: univData) {
            self.myUniversity = univ
        }
        
        // 3. 교육청 정보 로드
        if let officeRaw = UserDefaults.standard.string(forKey: "targetOffice"),
           let office = OfficeOfEducation(rawValue: officeRaw) {
            self.targetOffice = office
        }
    }
    
    // 맞춤 정보(대학교/교육청) 로컬 저장
    private func saveNoticeSettings() {
        if let univ = myUniversity, let encoded = try? JSONEncoder().encode(univ) {
            UserDefaults.standard.set(encoded, forKey: "myUniversity")
        } else {
            UserDefaults.standard.removeObject(forKey: "myUniversity")
        }
        
        if let office = targetOffice {
            UserDefaults.standard.set(office.rawValue, forKey: "targetOffice")
        } else {
            UserDefaults.standard.removeObject(forKey: "targetOffice")
        }
    }
    
    // 과목 정보 로컬 저장
    private func saveSubjectsToLocal() {
        let strings = favoriteSubjects.map { $0.name }
        UserDefaults.standard.set(strings, forKey: "localFavoriteSubjects")
    }
    
    // 기본 과목
    private func defaultSubjects() -> [StudySubject] {
        return [
            StudySubject(name: "교육학"),
            StudySubject(name: "전공"),
            StudySubject(name: "한국사")
        ]
    }
    
    // MARK: - 서버 동기화 (과목 데이터)
    
    func fetchSettings(uid: String) {
        let docRef = db.collection("users").document(uid).collection(settingsCollectionName).document(favoriteSubjectsDocument)
        
        docRef.getDocument { [weak self] document, error in
            guard let self = self else { return }
            
            if let document = document, document.exists, let data = document.data() {
                if let subjectStrings = data["subjects"] as? [String] {
                    let loadedSubjects = subjectStrings.map { StudySubject(name: $0) }
                    DispatchQueue.main.async {
                        self.favoriteSubjects = loadedSubjects
                        self.saveSubjectsToLocal() // 로컬도 최신화
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
    
    func saveFavoriteSubjects(uid: String, _ subjects: [StudySubject]) {
        self.favoriteSubjects = subjects
        self.saveSubjectsToLocal()
        
        let subjectStrings = subjects.map { $0.name }
        let dataToSave: [String: Any] = [
            "subjects": subjectStrings,
            "lastUpdated": Timestamp(date: Date())
        ]
        
        db.collection("users").document(uid).collection(settingsCollectionName).document(favoriteSubjectsDocument).setData(dataToSave)
    }
}
