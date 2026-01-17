import firebase_admin
from firebase_admin import credentials
from firebase_admin import firestore

def update_nickname(uid, new_nickname):
    try:
        cred = credentials.Certificate('scripts/serviceAccountKey.json')
        firebase_admin.initialize_app(cred)
    except Exception:
        pass

    db = firestore.client()
    user_ref = db.collection('users').document(uid)
    
    user_ref.update({
        "nickname": new_nickname
    })
    print(f"✅ Nickname updated to '{new_nickname}' for UID: {uid}")

if __name__ == "__main__":
    target_uid = "D03ERibLYsTROPu83PkB2JpkorD3"
    update_nickname(target_uid, "태태")
