import firebase_admin
from firebase_admin import credentials
from firebase_admin import firestore
import sys

def check_and_restore_user(uid):
    try:
        cred = credentials.Certificate('scripts/serviceAccountKey.json')
        firebase_admin.initialize_app(cred)
    except Exception as e:
        # Already initialized is fine
        pass

    db = firestore.client()
    
    print(f"🕵️ Checking status for UID: {uid}")
    
    # 1. Check User Document
    user_ref = db.collection('users').document(uid)
    user_doc = user_ref.get()
    
    if user_doc.exists:
        print("✅ User Profile Document EXISTS.")
        print(f"   Data: {user_doc.to_dict()}")
        return
    else:
        print("❌ User Profile Document is MISSING! (This is why data seems 'gone')")
        
        # 2. Restore User Document
        print("🛠 Restoring User Profile...")
        
        # 기본 프로필 데이터 복구
        # 기존 데이터를 100% 살릴 수는 없으므로(백업이 없다면), 필수 필드를 기본값으로 채워넣습니다.
        # 앱이 다시 작동하게 하기 위함입니다.
        restored_data = {
            "nickname": "돌아온티노",   # 임시 닉네임
            "email": "seoktae0526@naver.com",
            "createdAt": firestore.SERVER_TIMESTAMP,
            "university": "대학교 미설정",
            "teacherKnockID": "RESTORED", # 임시 ID
            "isPremium": False
        }
        
        user_ref.set(restored_data)
        print("✅ User Profile Restored! You should be able to see your data in the app now.")

if __name__ == "__main__":
    target_uid = "D03ERibLYsTROPu83PkB2JpkorD3"
    check_and_restore_user(target_uid)
