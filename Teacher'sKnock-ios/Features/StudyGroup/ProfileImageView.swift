import SwiftUI

struct ProfileImageView: View {
    let user: User
    let size: CGFloat
    
    // 프로필 이미지 이름 결정
    var profileImageName: String? {
        // ✨ 사용자가 티처스노크 로고 대신 기본 사람 모양 아이콘을 원함
        return nil
    }
    
    var body: some View {
        ZStack {
            // 1. 배경 (회색 원)
            Circle()
                .fill(Color.gray.opacity(0.1))
                .frame(width: size, height: size)
            
            // 2. 기본 로고 이미지
            if let imageName = profileImageName {
                Image(imageName)
                    .resizable()
                    .scaledToFill() // 꽉 채우기
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .opacity(0.7) // 은은하게
                    .grayscale(0.3) // 약간 무채색 톤으로
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
