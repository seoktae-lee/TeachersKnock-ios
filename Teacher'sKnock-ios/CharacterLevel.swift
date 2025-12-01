import Foundation
import SwiftUI

// 캐릭터 레벨 정의 (10단계 - 성취감 & 꾸준함 밸런스)
enum CharacterLevel: Int, CaseIterable {
    case lv1 = 0   // 시작 (0일)
    case lv2 = 1   // 10일 (초반 성취감!) - 작심삼일 3번 극복
    case lv3 = 2   // 30일 (한 달 달성) - 습관 형성 완료
    case lv4 = 3   // 60일 (두 달) - 기초 다지기
    case lv5 = 4   // 90일 (3개월 / 100일 전초전) - 실력 향상
    case lv6 = 5   // 120일 (4개월) - 흔들리지 않는 멘탈
    case lv7 = 6   // 150일 (5개월 / 반환점) - 전문가의 길
    case lv8 = 7   // 200일 (약 7개월) - 고지가 눈앞
    case lv9 = 8   // 250일 (약 8개월) - 라스트 스퍼트
    case lv10 = 9  // 300일 (대망의 합격) - 합격의 신
    
    // 레벨업에 필요한 진행률 (0.0 ~ 1.0)
    // * 목표 기간(D-day) 대비 몇 %를 달성했는지로 판단
    var requiredProgress: Double {
        switch self {
        case .lv1: return 0.0
        case .lv2: return 0.05  // 5% 진행 시 (빠른 성장)
        case .lv3: return 0.10  // 10%
        case .lv4: return 0.20  // 20%
        case .lv5: return 0.35
        case .lv6: return 0.50  // 반환점
        case .lv7: return 0.65
        case .lv8: return 0.80
        case .lv9: return 0.90  // 막판 스퍼트
        case .lv10: return 1.0  // 완주
        }
    }
    
    // 레벨별 칭호 (동기부여 멘트)
    var title: String {
        switch self {
        case .lv1: return "설레는 시작"
        case .lv2: return "튼튼한 새싹"
        case .lv3: return "한 달의 끈기"
        case .lv4: return "성실의 아이콘"
        case .lv5: return "지치지 않는 열정"
        case .lv6: return "피어나는 재능"
        case .lv7: return "반환점 돌파!"
        case .lv8: return "무르익은 실력"
        case .lv9: return "비상의 준비"
        case .lv10: return "합격의 신"
        }
    }
    
    // 레벨별 이모지 (성장 서사: 알 -> 새싹 -> 나무 -> 꽃 -> 열매 -> 새 -> 비행기 -> 왕관)
    var emoji: String {
        switch self {
        case .lv1: return "🥚"      // 알
        case .lv2: return "🌱"      // 새싹
        case .lv3: return "🌿"      // 잎사귀
        case .lv4: return "🌳"      // 나무
        case .lv5: return "💧"      // 물주기(노력)
        case .lv6: return "🌺"      // 꽃
        case .lv7: return "🍎"      // 열매 (사과=교사 상징)
        case .lv8: return "🦅"      // 독수리 (높은 곳으로)
        case .lv9: return "🚀"      // 로켓 (합격 기원)
        case .lv10: return "👑"     // 왕관 (합격)
        }
    }
    
    // 레벨 계산기 (공부 일수와 전체 목표 일수를 받아서 레벨 반환)
    static func getLevel(currentDays: Int, totalGoalDays: Int) -> CharacterLevel {
        if totalGoalDays == 0 { return .lv1 }
        
        let progress = Double(currentDays) / Double(totalGoalDays)
        
        // 높은 레벨부터 거꾸로 확인하여 조건에 맞으면 해당 레벨 반환
        for level in CharacterLevel.allCases.reversed() {
            if progress >= level.requiredProgress {
                return level
            }
        }
        return .lv1
    }
}
