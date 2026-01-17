import firebase_admin
from firebase_admin import credentials
from firebase_admin import firestore
import sys
import datetime

def check_orphaned_data(uid):
    try:
        cred = credentials.Certificate('scripts/serviceAccountKey.json')
        firebase_admin.initialize_app(cred)
    except Exception as e:
        print(f"Auth Error: {e}")
        return

    db = firestore.client()
    
    print(f"🔍 Searching for orphaned data for UID: {uid}\n")
    
    # Check User Doc existence (Should be missing)
    user_doc = db.collection('users').document(uid).get()
    if user_doc.exists:
        print("⚠️ User document STILL EXISTS (It was not fully deleted?)")
        user_data = user_doc.to_dict()
        print(f"   Nickname: {user_data.get('nickname')}")
        print(f"   Univ: {user_data.get('university')}")
    else:
        print("✅ User document is DELETED (As expected for a withdrawn account)")
    
    print("-" * 40)

    # 1. Schedules
    schedules_ref = db.collection('users').document(uid).collection('schedules')
    schedules = list(schedules_ref.stream())
    print(f"📅 Schedules found: {len(schedules)}")
    for doc in schedules[:5]: # Show first 5
        data = doc.to_dict()
        title = data.get('title', 'No Title')
        subject = data.get('subject', 'No Subject')
        print(f"   - {title} ({subject})")
    if len(schedules) > 5: print(f"   ... and {len(schedules) - 5} more")
    print("")

    # 2. Study Records
    records_ref = db.collection('users').document(uid).collection('study_records')
    records = list(records_ref.stream())
    print(f"📖 Study Records found: {len(records)}")
    if len(records) > 0:
        total_time = sum([r.to_dict().get('durationSeconds', 0) for r in records])
        print(f"   - Total Study Time: {total_time // 3600}h {(total_time % 3600) // 60}m")
    print("")

    # 3. Notes (DailyNote)
    notes_ref = db.collection('users').document(uid).collection('notes')
    notes = list(notes_ref.stream())
    print(f"📝 Daily Notes found: {len(notes)}")
    for doc in notes[:3]:
        data = doc.to_dict()
        emotion = data.get('emotion', 'No Emotion')
        content = data.get('content', '')
        # Handle timestamp
        date_val = data.get('date')
        date_str = "Unknown Date"
        if date_val:
            # Assuming it's a datetime object from firestore
            try:
                date_str = date_val.strftime("%Y-%m-%d")
            except:
                date_str = str(date_val)
                
        print(f"   - {date_str}: {emotion} {content[:20]}...")
    print("")

if __name__ == "__main__":
    target_uid = "D03ERibLYsTROPu83PkB2JpkorD3"
    check_orphaned_data(target_uid)
