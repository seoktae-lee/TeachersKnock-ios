import Foundation
import SwiftUI

// 1. 교육청 데이터 (전국 17개 시도 교육청 - 초등/중등 공통)
enum OfficeOfEducation: String, CaseIterable, Identifiable, Codable {
    case seoul = "서울시교육청"
    case gyeonggi = "경기도교육청"
    case busan = "부산시교육청"
    case daegu = "대구시교육청"
    case incheon = "인천시교육청"
    case gwangju = "광주시교육청"
    case daejeon = "대전시교육청"
    case ulsan = "울산시교육청"
    case sejong = "세종시교육청"
    case gangwon = "강원도교육청"
    case chungbuk = "충북교육청"
    case chungnam = "충남교육청"
    case jeonbuk = "전북교육청"
    case jeonnam = "전남교육청"
    case gyeongbuk = "경북교육청"
    case gyeongnam = "경남교육청"
    case jeju = "제주도교육청"
    
    var id: String { self.rawValue }
    
    // 각 교육청의 '시험 정보' 또는 '인사/채용' 게시판 URL
    var urlString: String {
        switch self {
        case .seoul: return "https://www.sen.go.kr/web/services/bbs/bbsList.action?bbsBean.bbsCd=72" // 서울 중등/초등 임용 게시판
        case .gyeonggi: return "https://www.goe.go.kr/edu/job/selectJobList.do?menuId=280151205123486" // 경기 시험정보
        // ... (나머지 교육청은 검색 링크로 대체, 추후 정확한 URL로 업데이트 권장)
        default: return "https://www.google.com/search?q=\(self.rawValue)+초등임용공고"
        }
    }
    
    // ✨ 교육청 로고 이미지 이름 (Assets에 해당 이름의 이미지가 있어야 함)
    // 없을 경우 뷰에서 기본 앱 로고를 대신 사용하도록 처리
    var logoImageName: String {
        return "OfficeLogo_\(self.rawValue)" // 다시 한글 이름 사용 (파일이 한글로 되어있음)
    }
    
}

// 2. ✨ [수정됨] 대학교 데이터 (전국 교대 및 초등교육과)
struct University: Identifiable, Codable, Hashable {
    var id: String { name }
    let name: String
    let urlString: String
    
    // 🔍 초등 임용 준비생을 위한 전국 교대 리스트
    static let allList: [University] = [
        University(name: "서울교육대학교", urlString: "https://www.snue.ac.kr"),
        University(name: "경인교육대학교", urlString: "https://www.ginue.ac.kr"),
        University(name: "춘천교육대학교", urlString: "https://www.cnue.ac.kr"),
        University(name: "청주교육대학교", urlString: "https://www.cje.ac.kr"),
        University(name: "공주교육대학교", urlString: "https://www.gjue.ac.kr"),
        University(name: "전주교육대학교", urlString: "https://www.jnue.ac.kr"),
        University(name: "광주교육대학교", urlString: "https://www.gnue.ac.kr"),
        University(name: "대구교육대학교", urlString: "https://www.dnue.ac.kr"),
        University(name: "부산교육대학교", urlString: "https://www.bnue.ac.kr"),
        University(name: "진주교육대학교", urlString: "https://www.cue.ac.kr"),
        University(name: "한국교원대학교 (초등)", urlString: "https://www.knue.ac.kr"),
        University(name: "이화여자대학교 (초등)", urlString: "https://cms.ewha.ac.kr/user/indexMain.action?siteId=elementary"),
        University(name: "제주대학교 (교육대학)", urlString: "https://en.jeju.ac.kr")
    ]
    
    // 이름으로 객체 찾기 헬퍼 함수
    static func find(byName name: String) -> University? {
        return allList.first { $0.name == name }
    }
}

// 3. 공통 필수 사이트 (평가원, 교육부 등)
struct CommonSite: Identifiable {
    let id = UUID()
    let name: String
    let urlString: String
    let iconName: String
    let color: Color
    
    static let all: [CommonSite] = [
        CommonSite(name: "한국교육과정평가원 (KICE)", urlString: "https://www.kice.re.kr", iconName: "book.closed.fill", color: .green),
        CommonSite(name: "교육부 (보도자료)", urlString: "https://www.moe.go.kr", iconName: "building.columns.fill", color: .blue),
        CommonSite(name: "티처빌 (연수원)", urlString: "https://www.teacherville.co.kr", iconName: "play.tv.fill", color: .orange) // 예시 추가
    ]
}
