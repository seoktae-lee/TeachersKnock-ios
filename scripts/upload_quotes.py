
import firebase_admin
from firebase_admin import credentials
from firebase_admin import firestore
import json
import random
import sys

# ---------------------------------------------------------
# [사용 방법]
# 1. Firebase 콘솔 > 프로젝트 설정 > 서비스 계정 > 새 비공개 키 생성
# 2. 다운로드 받은 JSON 파일 이름을 'serviceAccountKey.json'으로 변경하고
#    이 스크립트와 같은 폴더(scripts/)에 놓아주세요.
# 3. 터미널에서 다음 명령어로 필수 라이브러리를 설치하세요:
#    pip3 install firebase-admin
# 4. 스크립트 실행:
#    python3 scripts/upload_quotes.py
# ---------------------------------------------------------

def upload_quotes():
    # 1. Firebase Admin SDK 초기화
    try:
        # 서비스 계정 키 파일 경로 (상대 경로)
        cred = credentials.Certificate('scripts/serviceAccountKey.json')
        firebase_admin.initialize_app(cred)
        print("✅ Firebase 접속 성공!")
    except Exception as e:
        print(f"❌ Firebase 초기화 실패: {e}")
        print("💡 'serviceAccountKey.json' 파일이 scripts 폴더 안에 있는지 확인해주세요.")
        return

    db = firestore.client()

    # 2. JSON 파일 읽기
    json_path = 'scripts/quotes.json'
    try:
        with open(json_path, 'r', encoding='utf-8') as f:
            quotes_list = json.load(f)
            print(f"📂 '{json_path}' 로드 완료. 총 {len(quotes_list)}개의 명언이 있습니다.")
    except Exception as e:
        print(f"❌ JSON 파일 로드 실패: {e}")
        return

    # 3. 데이터 업로드 (Batch 이용)
    # 기존 데이터를 싹 지우고 새로 올릴지, 아니면 추가만 할지 결정해야 합니다.
    # 여기서는 '덮어쓰기' 모드로, 인덱스를 0부터 다시 매깁니다.
    
    print("\n🚀 데이터 업로드 시작...")
    
    batch = db.batch()
    quotes_ref = db.collection('quotes')

    # (선택) 안전을 위해 기존 데이터를 먼저 삭제하려면 별도 로직이 필요하지만,
    # 여기서는 간단하게 0부터 덮어쓰거나 추가합니다.
    # 운영 중엔 '이어쓰기'가 나을 수 있지만, 지금은 초기 세팅이므로 0부터 시작합니다.

    count = 0
    total = len(quotes_list)
    
    # 리스트를 한 번 섞어서 매번 순서가 다르도록 (옵션)
    # random.shuffle(quotes_list) 

    for idx, item in enumerate(quotes_list):
        # 문서 ID를 'quote_0', 'quote_1' 식으로 지정하여 중복 방지 및 확인 용이
        doc_ref = quotes_ref.document(f"quote_{idx}")
        
        doc_data = {
            "index": idx,
            "text": item['text'],
            "author": item['author']
        }
        
        batch.set(doc_ref, doc_data)
        count += 1
        
        # Firestore batch는 한 번에 최대 500개까지만 가능
        if count % 400 == 0:
            batch.commit()
            batch = db.batch()
            print(f"   running... {count}/{total} 업로드 중")

    # 남은 배치 실행
    if count % 400 != 0:
        batch.commit()

    print(f"✅ {count}개의 명언 업로드 완료!")

    # 4. 메타데이터 업데이트 (총 개수 저장)
    metadata_ref = db.collection('metadata').document('quotes_info')
    metadata_ref.set({
        "total_count": count,
        "last_updated": firestore.SERVER_TIMESTAMP
    })
    
    print(f"✅ 메타데이터 업데이트 완료 (total_count: {count})")
    print("\n🎉 모든 작업이 끝났습니다.")

if __name__ == "__main__":
    upload_quotes()
