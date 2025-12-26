import SwiftUI
import SwiftData
import FirebaseAuth

struct TimerView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var settingsManager: SettingsManager
    
    // ✨ ViewModel 연결 (StateObject로 수명 관리)
    @StateObject private var viewModel = TimerViewModel()
    
    private let brandColor = Color(red: 0.35, green: 0.65, blue: 0.95)
    
    private var currentUserId: String {
        Auth.auth().currentUser?.uid ?? ""
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Spacer().frame(height: 30)
                
                // 1. 과목 및 목적 선택 영역 (✨ 디자인 수정됨: 더 크고 시원하게)
                HStack(spacing: 15) {
                    // 과목 선택
                    VStack(spacing: 8) {
                        Text("과목").font(.caption).foregroundColor(.gray)
                        Menu {
                            ForEach(settingsManager.favoriteSubjects) { subject in
                                Button(subject.localizedName) {
                                    viewModel.selectedSubject = subject.localizedName
                                }
                            }
                            Divider()
                            NavigationLink(destination: SubjectSelectView()) {
                                Label("과목 설정 편집", systemImage: "gearshape")
                            }
                        } label: {
                            HStack {
                                Text(viewModel.selectedSubject)
                                    .font(.title3)        // ✨ 폰트 키움
                                    .fontWeight(.bold)    // ✨ 두껍게
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.5)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.down")
                                    .font(.body)
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 16)       // ✨ 높이(터치 영역) 확대
                            .padding(.horizontal, 20)
                            .frame(maxWidth: .infinity)   // ✨ 가로 꽉 채우기
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(16)
                        }
                    }
                    
                    // 목적 선택
                    VStack(spacing: 8) {
                        Text("공부 목적").font(.caption).foregroundColor(.gray)
                        Menu {
                            ForEach(StudyPurpose.orderedCases, id: \.self) { purpose in
                                Button(purpose.localizedName) {
                                    viewModel.selectedPurpose = purpose
                                }
                            }
                        } label: {
                            HStack {
                                Text(viewModel.selectedPurpose.localizedName)
                                    .font(.title3)        // ✨ 폰트 키움
                                    .fontWeight(.bold)    // ✨ 두껍게
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.5)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.down")
                                    .font(.body)
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 16)       // ✨ 높이(터치 영역) 확대
                            .padding(.horizontal, 20)
                            .frame(maxWidth: .infinity)   // ✨ 가로 꽉 채우기
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(16)
                        }
                    }
                }
                .padding(.horizontal, 20) // ✨ 전체 좌우 여백 조정
                .disabled(viewModel.isRunning) // 공부 중엔 변경 불가
                .opacity(viewModel.isRunning ? 0.6 : 1.0)
                
                Spacer()
                
                // 2. ✨ 타이머 시간 표시
                Text(viewModel.formatTime(seconds: viewModel.displayTime))
                    .font(.system(size: 90, weight: .medium, design: .monospaced))
                    .foregroundColor(viewModel.isRunning ? brandColor : .primary)
                    .lineLimit(1).minimumScaleFactor(0.5)
                    .padding(.horizontal)
                    .contentTransition(.numericText()) // 숫자 바뀔 때 부드럽게
                
                Spacer()
                
                // 3. 컨트롤 버튼
                HStack(spacing: 40) {
                    if viewModel.isRunning {
                        // 일시정지 버튼
                        Button(action: { viewModel.stopTimer() }) {
                            VStack {
                                Image(systemName: "pause.circle.fill").resizable().frame(width: 80, height: 80)
                                Text("일시정지").font(.caption).padding(.top, 5)
                            }
                        }
                        .foregroundColor(.orange)
                    } else {
                        // 시작 버튼
                        Button(action: { viewModel.startTimer() }) {
                            VStack {
                                Image(systemName: "play.circle.fill").resizable().frame(width: 80, height: 80)
                                Text(viewModel.displayTime > 0 ? "계속하기" : "시작").font(.caption).padding(.top, 5)
                            }
                        }
                        .foregroundColor(brandColor)
                    }
                    
                    // 완료 및 저장 버튼
                    if !viewModel.isRunning && viewModel.displayTime > 0 {
                        Button(action: {
                            viewModel.saveRecord(context: modelContext, ownerID: currentUserId)
                        }) {
                            VStack {
                                Image(systemName: "checkmark.circle.fill").resizable().frame(width: 80, height: 80)
                                Text("저장하기").font(.caption).padding(.top, 5)
                            }
                        }
                        .foregroundColor(.green)
                    }
                }
                .padding(.bottom, 20)
                
                // 4. 최근 기록 리스트
                RecentRecordsView(userId: currentUserId)
                    .padding(.bottom, 10)
            }
            .navigationTitle("집중 타이머")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    // 통계 버튼
                    NavigationLink(destination: StatisticsView(userId: currentUserId)) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.title3)
                            .foregroundColor(brandColor)
                    }
                }
            }
            // 화면이 나타날 때 초기 과목 설정
            .onAppear {
                viewModel.setupInitialSubject(favorites: settingsManager.favoriteSubjects)
            }
            // 화면 나갈 때 타이머 자동 정지
            .onDisappear {
                if viewModel.isRunning { viewModel.stopTimer() }
            }
        }
    }
}

// RecentRecordsView (기존과 동일)
struct RecentRecordsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var records: [StudyRecord]
    
    init(userId: String) {
        _records = Query(filter: #Predicate<StudyRecord> { record in
            record.ownerID == userId
        }, sort: \.date, order: .reverse)
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("최근 학습 기록").font(.headline).padding(.horizontal).padding(.bottom, 5)
            List {
                if records.isEmpty {
                    Text("아직 기록이 없습니다.").foregroundColor(.gray)
                } else {
                    ForEach(records.prefix(10)) { record in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(record.areaName).font(.subheadline).bold()
                                Text(record.studyPurpose).font(.caption2).foregroundColor(.gray).padding(.horizontal, 6).padding(.vertical, 2).background(Color.gray.opacity(0.1)).cornerRadius(4)
                            }
                            Spacer()
                            if record.durationSeconds >= 3600 {
                                Text("\(record.durationSeconds / 3600)시간 \((record.durationSeconds % 3600) / 60)분").font(.caption).foregroundColor(.gray)
                            } else {
                                Text("\(record.durationSeconds / 60)분 \(record.durationSeconds % 60)초").font(.caption).foregroundColor(.gray)
                            }
                        }
                    }
                    .onDelete(perform: deleteRecords)
                }
            }
            .listStyle(.plain).frame(height: 200)
        }
    }
    
    private func deleteRecords(offsets: IndexSet) {
        for index in offsets { modelContext.delete(records[index]) }
    }
}
