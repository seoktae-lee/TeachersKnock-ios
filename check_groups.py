import firebase_admin
from firebase_admin import credentials
from firebase_admin import firestore

def check_study_groups(uid):
    try:
        cred = credentials.Certificate('scripts/serviceAccountKey.json')
        firebase_admin.initialize_app(cred)
    except Exception:
        pass

    db = firestore.client()
    
    print(f"🕵️ Checking study groups for UID: {uid}")
    
    # 해당 UID가 members 배열에 포함된 그룹 찾기
    groups_ref = db.collection('study_groups')
    query = groups_ref.where('members', 'array_contains', uid)
    results = list(query.stream())
    
    if not results:
        print("❌ You are NOT a member of any study group.")
        print("   (Reason: Membership was likely removed during account deletion process)")
    else:
        print(f"✅ Found {len(results)} study groups you are in:")
        for doc in results:
            data = doc.to_dict()
            print(f"   - Group Name: {data.get('name', 'Unknown')}")
            print(f"     ID: {doc.id}")
            print(f"     Role: {'Leader' if data.get('leaderID') == uid else 'Member'}")

if __name__ == "__main__":
    target_uid = "D03ERibLYsTROPu83PkB2JpkorD3"
    check_study_groups(target_uid)
