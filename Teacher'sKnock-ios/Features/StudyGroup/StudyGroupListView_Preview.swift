import SwiftUI

struct StudyGroupListView_Previews: PreviewProvider {
    static var previews: some View {
        StudyGroupListView(invitationManager: InvitationManager(), friendRequestManager: FriendRequestManager())
    }
}
