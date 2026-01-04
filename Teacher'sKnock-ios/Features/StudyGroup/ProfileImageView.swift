import SwiftUI

struct ProfileImageView: View {
    let user: User
    let size: CGFloat
    
    // 프로필 이미지 이름 결정
    var profileImageName: String? {
        if let office = user.targetOffice, !office.isEmpty {
            return "OfficeLogo_\(office)"
        }
        return "TeachersKnockLogo"
    }
    
    var body: some View {
        ZStack {
            // 1. 배경 (회색 원)
            Circle()
                .fill(Color.gray.opacity(0.1))
                .frame(width: size, height: size)
            
            // 2. 로고 이미지 (글씨 자르고 로고만 확대)
            if let imageName = profileImageName {
                Image(imageName)
                    .resizable()
                    .scaledToFill() // 꽉 채우기
                    .frame(width: size, height: size)
                    .scaleEffect(1.8) // ✨ 조금 더 확대
                    .offset(x: size * 0.5) // ✨ 왼쪽 심볼이 중앙에 오도록 이미지를 오른쪽으로 이동 (로고 형태에 따라 값 조절 필요)
                    .clipShape(Circle())
                    .opacity(0.7) // 은은하게
                    .grayscale(0.3) // 약간 무채색 톤으로 눌러줌 (라인아트 느낌 내기 위해)
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: size, height: size)
                    .foregroundColor(.gray.opacity(0.5))
            }
            
            // 3. 테두리
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                .frame(width: size, height: size)
        }
    }
}
