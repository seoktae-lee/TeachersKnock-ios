import firebase_admin
from firebase_admin import credentials
from firebase_admin import firestore

def delete_collection(coll_ref, batch_size):
    docs = list(coll_ref.limit(batch_size).stream())
    deleted = 0

    if len(docs) > 0:
        for doc in docs:
            print(f'Deleting doc {doc.id} => {doc.to_dict().get("emotion","")}')
            doc.reference.delete()
            deleted = deleted + 1
        
        # Recursively delete rest
        if deleted >= batch_size:
            return delete_collection(coll_ref, batch_size)
    return deleted

def delete_emotional_notes(uid):
    try:
        cred = credentials.Certificate('scripts/serviceAccountKey.json')
        firebase_admin.initialize_app(cred)
    except Exception as e:
        print(f"Auth Error: {e}")
        return

    db = firestore.client()
    
    print(f"🗑 Removing 'notes' data for UID: {uid}\n")
    
    notes_ref = db.collection('users').document(uid).collection('notes')
    
    deleted_count = delete_collection(notes_ref, 10)
    print(f"-"*30)
    print(f"✅ Deleted {deleted_count} notes.")

if __name__ == "__main__":
    target_uid = "D03ERibLYsTROPu83PkB2JpkorD3"
    delete_emotional_notes(target_uid)
