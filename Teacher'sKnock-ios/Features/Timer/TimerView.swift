import SwiftUI
import SwiftData
import FirebaseAuth

struct TimerView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var navManager: StudyNavigationManager
    @StateObject private var viewModel = TimerViewModel()
    
    private let brandColor = Color(red: 0.35, green: 0.65, blue: 0.95)
    private var currentUserId: String { Auth.auth().currentUser?.uid ?? "" }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Spacer().frame(height: 30)
                
                // 1. 과목 및 목적 선택 영역
                HStack(spacing: 15) {
                    
                    // 과목 선택 메뉴 (통합 버전)
                    VStack(spacing: 8) {
                        Text("과목").font(.caption).foregroundColor(.gray)
                        
                        Menu {
                            // (1) 현재 등록된 모든 과목 (13개 기본 + 사용자 추가)
                            ForEach(settingsManager.favoriteSubjects) { subject in
                                Button(action: {
                                    viewModel.selectedSubject = subject.name
                                }) {
                                    HStack {
                                        Text(subject.name)
                                        if viewModel.selectedSubject == subject.name {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                            
                            Divider()
                            
                            // (2) 과목 추가/삭제 관리 화면으로 이동
                            NavigationLink(destination: SubjectManagementView()) {
                                Label("과목 추가/관리", systemImage: "plus.circle")
                            }
                            
                        } label: {
                            HStack {
                                Text(viewModel.selectedSubject)
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.5)
                                    // 선택된 과목 색상 적용
                                    .foregroundColor(SubjectName.color(for: viewModel.selectedSubject))
                                
                                Spacer()
                                
                                Image(systemName: "chevron.down")
                                    .font(.body)
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 16)
                            .padding(.horizontal, 20)
                            .frame(maxWidth: .infinity)
                            .background(Color.white)
                            .cornerRadius(16)
                            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                        }
                    }
                    
                    // 목적 선택
                    VStack(spacing: 8) {
                        Text("공부 목적").font(.caption).foregroundColor(.gray)
                        
                        if viewModel.linkedScheduleTitle != nil {
                            Button(action: { viewModel.linkedScheduleTitle = nil }) {
                                HStack {
                                    Text(viewModel.selectedPurpose.localizedName)
                                        .font(.title3).fontWeight(.bold)
                                        .lineLimit(1).minimumScaleFactor(0.5)
                                        .foregroundColor(.white)
                                    Spacer()
                                    Image(systemName: "xmark.circle.fill").foregroundColor(.white.opacity(0.8))
                                }
                                .padding(.vertical, 16).padding(.horizontal, 20)
                                .frame(maxWidth: .infinity)
                                .background(brandColor).cornerRadius(16)
                            }
                        } else {
                            Menu {
                                ForEach(StudyPurpose.orderedCases, id: \.self) { purpose in
                                    Button(purpose.localizedName) { viewModel.selectedPurpose = purpose }
                                }
                            } label: {
                                HStack {
                                    Text(viewModel.selectedPurpose.localizedName)
                                        .font(.title3).fontWeight(.bold)
                                        .lineLimit(1).minimumScaleFactor(0.5)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.down").font(.body).foregroundColor(.gray)
                                }
                                .padding(.vertical, 16).padding(.horizontal, 20)
                                .frame(maxWidth: .infinity)
                                .background(Color.white).cornerRadius(16)
                                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .disabled(viewModel.isRunning)
                .opacity(viewModel.isRunning ? 0.6 : 1.0)
                
                Spacer()
                
                // 2. 타이머 시간 표시
                Text(viewModel.formatTime(seconds: viewModel.displayTime))
                    .font(.system(size: 90, weight: .medium, design: .monospaced))
                    .foregroundColor(viewModel.isRunning ? brandColor : .primary)
                    .lineLimit(1).minimumScaleFactor(0.5)
                    .padding(.horizontal)
                    .contentTransition(.numericText())
                
                Spacer()
                
                // 3. 컨트롤 버튼
                HStack(spacing: 40) {
                    if viewModel.isRunning {
                        Button(action: { viewModel.stopTimer() }) {
                            VStack {
                                Image(systemName: "pause.circle.fill").resizable().frame(width: 80, height: 80)
                                Text("일시정지").font(.caption).padding(.top, 5)
                            }
                        }.foregroundColor(.orange)
                    } else {
                        Button(action: { viewModel.startTimer() }) {
                            VStack {
                                Image(systemName: "play.circle.fill").resizable().frame(width: 80, height: 80)
                                Text(viewModel.displayTime > 0 ? "계속하기" : "시작").font(.caption).padding(.top, 5)
                            }
                        }.foregroundColor(brandColor)
                    }
                    
                    if !viewModel.isRunning && viewModel.displayTime > 0 {
                        Button(action: { viewModel.saveRecord(context: modelContext, ownerID: currentUserId) }) {
                            VStack {
                                Image(systemName: "checkmark.circle.fill").resizable().frame(width: 80, height: 80)
                                Text("저장하기").font(.caption).padding(.top, 5)
                            }
                        }.foregroundColor(.green)
                    }
                }
                .padding(.bottom, 20)
                
                // 4. 최근 기록 리스트 (오류 해결됨 ✅)
                RecentRecordsView(userId: currentUserId).padding(.bottom, 10)
            }
            .background(Color(.systemGray6))
            .navigationTitle("집중 타이머")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: StatisticsView(userId: currentUserId)) {
                        Image(systemName: "chart.bar.xaxis").font(.title3).foregroundColor(brandColor)
                    }
                }
            }
            .onAppear {
                // 초기 과목 설정: 없으면 "교직논술"
                if viewModel.selectedSubject.isEmpty || !settingsManager.favoriteSubjects.map({$0.name}).contains(viewModel.selectedSubject) {
                    viewModel.selectedSubject = settingsManager.favoriteSubjects.first?.name ?? "교직논술"
                }
                if let schedule = navManager.targetSchedule {
                    viewModel.applySchedule(schedule)
                    navManager.clearTarget()
                }
            }
            .onChange(of: navManager.targetSchedule) { _, newValue in
                if let schedule = newValue {
                    viewModel.applySchedule(schedule)
                    navManager.clearTarget()
                }
            }
            .onDisappear { if viewModel.isRunning { viewModel.stopTimer() } }
        }
    }
}

// ✨ [누락되었던 부분] 최근 기록 리스트 뷰 정의
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
