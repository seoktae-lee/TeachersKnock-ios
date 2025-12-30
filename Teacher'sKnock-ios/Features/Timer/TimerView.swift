import SwiftUI
import SwiftData
import FirebaseAuth

struct TimerView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var navManager: StudyNavigationManager
    @StateObject private var viewModel = TimerViewModel()
    
    // ✨ 목표 데이터를 가져와 저장 시 연결하기 위함
    @Query(sort: \Goal.targetDate) private var goals: [Goal]
    
    private let brandColor = Color(red: 0.35, green: 0.65, blue: 0.95)
    private var currentUserId: String { Auth.auth().currentUser?.uid ?? "" }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Spacer().frame(height: 30)
                
                // 1. 과목 및 목적 선택 영역
                HStack(spacing: 15) {
                    VStack(spacing: 8) {
                        Text("과목").font(.caption).foregroundColor(.gray)
                        
                        Menu {
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
                                    .foregroundColor(SubjectName.color(for: viewModel.selectedSubject))
                                Spacer()
                                Image(systemName: "chevron.down").font(.body).foregroundColor(.gray)
                            }
                            .padding(.vertical, 16)
                            .padding(.horizontal, 20)
                            .frame(maxWidth: .infinity)
                            .background(Color.white)
                            .cornerRadius(16)
                            .shadow(color: .black.opacity(0.05), radius: 5)
                        }
                    }
                    
                    VStack(spacing: 8) {
                        Text("공부 목적").font(.caption).foregroundColor(.gray)
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
                            .shadow(color: .black.opacity(0.05), radius: 5)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .disabled(viewModel.isRunning)
                .opacity(viewModel.isRunning ? 0.6 : 1.0)
                
                Spacer()
                
                // 2. 타이머 시간 표시
                Text(viewModel.timeString)
                    .font(.system(size: 90, weight: .medium, design: .monospaced))
                    .foregroundColor(viewModel.isRunning ? brandColor : .primary)
                    .lineLimit(1).minimumScaleFactor(0.5)
                
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
                        Button(action: {
                            let primaryGoal = goals.first { $0.isPrimaryGoal } ?? goals.first
                            viewModel.saveRecord(context: modelContext, ownerID: currentUserId, primaryGoal: primaryGoal)
                        }) {
                            VStack {
                                Image(systemName: "checkmark.circle.fill").resizable().frame(width: 80, height: 80)
                                Text("저장하기").font(.caption).padding(.top, 5)
                            }
                        }.foregroundColor(.green)
                    }
                }
                .padding(.bottom, 20)
                
                // ✅ [오류 해결] 1. RecentRecordsView를 하단에 정의 / 2. .bottom으로 마침표 추가
                RecentRecordsView(userId: currentUserId).padding(.bottom, 10)
            }
            .background(Color(.systemGray6))
            .navigationTitle("집중 타이머")
            .onAppear {
                if viewModel.selectedSubject.isEmpty {
                    viewModel.selectedSubject = settingsManager.favoriteSubjects.first?.name ?? "교직논술"
                }
                if let schedule = navManager.targetSchedule {
                    viewModel.applySchedule(schedule)
                    navManager.clearTarget()
                }
            }
            // ✨ [추가] 이미 타이머 탭에 있을 때 딥링크로 데이터가 들어오면 즉시 반영
            .onChange(of: navManager.targetSchedule) { newSchedule in
                if let schedule = newSchedule {
                    viewModel.applySchedule(schedule)
                    navManager.clearTarget()
                }
            }

        }

    }
}

// MARK: - RecentRecordsView (누락된 뷰 정의 추가)
struct RecentRecordsView: View {
    let userId: String
    @Query private var records: [StudyRecord]
    
    init(userId: String) {
        self.userId = userId
        // 해당 유저의 최근 기록 5개만 가져오기
        _records = Query(filter: #Predicate<StudyRecord> { $0.ownerID == userId }, sort: \.date, order: .reverse)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("최근 공부 기록").font(.headline)
                Spacer()
                NavigationLink(destination: StatisticsView(userId: userId)) {
                    HStack(spacing: 4) {
                        Image(systemName: "chart.bar.xaxis")
                        Text("통계")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(Color(red: 0.35, green: 0.65, blue: 0.95))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal)
            
            if records.isEmpty {
                Text("아직 기록이 없습니다.")
                    .font(.caption).foregroundColor(.secondary)
                    .frame(maxWidth: .infinity).padding()
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(records.prefix(5)) { record in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(record.areaName).font(.subheadline).bold()
                                    Text(record.date.formatted(date: .abbreviated, time: .shortened)).font(.caption2).foregroundColor(.gray)
                                }
                                Spacer()
                                Text("\(record.durationSeconds / 60)분").font(.subheadline).bold()
                            }
                            .padding().background(Color.white).cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(height: 180)
            }
        }
    }
}
