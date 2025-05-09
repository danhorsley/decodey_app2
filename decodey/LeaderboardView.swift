import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct LeaderboardView: View {
    // MARK: - State
    @State private var leaderboardEntries: [NetworkManager.LeaderboardEntry] = []
    @State private var period: String = "weekly"
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var currentUserRank: Int? = nil
    @State private var periodInfo: (start: String, end: String) = ("", "")
    
    // MARK: - UI Styling
    private let colors = ColorSystem.shared
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationView {
            ZStack {
                colors.primaryBackground(for: colorScheme)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Period selection
                    Picker("Time Period", selection: $period) {
                        Text("Weekly").tag("weekly")
                        Text("All Time").tag("all_time")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    
                    // Period dates
                    if !periodInfo.start.isEmpty {
                        Text(getPeriodDisplayText())
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 8)
                    }
                    
                    // Current user rank
                    if let rank = currentUserRank {
                        HStack(spacing: 12) {
                            Image(systemName: "person.fill")
                                .foregroundColor(colors.accent)
                            
                            Text("Your Rank: \(rank)")
                                .fontWeight(.bold)
                                .foregroundColor(colors.primaryText(for: colorScheme))
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(colors.secondaryBackground(for: colorScheme))
                        )
                        .padding(.bottom, 10)
                    }
                    
                    // Leaderboard list
                    if isLoading {
                        Spacer()
                        ProgressView("Loading leaderboard...")
                            .progressViewStyle(CircularProgressViewStyle())
                        Spacer()
                    } else if let error = errorMessage {
                        Spacer()
                        VStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.largeTitle)
                                .foregroundColor(.orange)
                            
                            Text("Error loading leaderboard")
                                .font(.headline)
                            
                            Text(error)
                                .font(.subheadline)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                            
                            Button("Try Again") {
                                loadLeaderboard()
                            }
                            .padding(.top, 10)
                            .foregroundColor(colors.accent)
                        }
                        Spacer()
                    } else if leaderboardEntries.isEmpty {
                        Spacer()
                        Text("No leaderboard entries found")
                            .foregroundColor(.secondary)
                        Spacer()
                    } else {
                        // Header row
                        leaderboardHeaderRow
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(colors.secondaryBackground(for: colorScheme))
                        
                        List {
                            ForEach(leaderboardEntries) { entry in
                                LeaderboardRow(
                                    entry: entry,
                                    isCurrentUser: entry.rank == currentUserRank
                                )
                            }
                            .listRowBackground(colors.primaryBackground(for: colorScheme))
                        }
                        .listStyle(PlainListStyle())
                    }
                }
                .padding(.top)
            }
            #if os(iOS)
            .navigationBarTitle("Leaderboard", displayMode: .inline)
            #else
            .navigationTitle("Leaderboard")
            #endif
            .onChange(of: period) { newValue in
                loadLeaderboard()
            }
            .onAppear {
                loadLeaderboard()
            }
        }
    }
    
    // MARK: - Header Row
    private var leaderboardHeaderRow: some View {
        HStack {
            Text("Rank")
                .frame(width: 60, alignment: .center)
                .font(.caption.bold())
            
            Text("Player")
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.caption.bold())
            
            Text("Score")
                .frame(width: 80, alignment: .trailing)
                .font(.caption.bold())
        }
    }
    
    // MARK: - Helper Functions
    
    private func loadLeaderboard() {
        isLoading = true
        errorMessage = nil
        
        NetworkManager.shared.fetchLeaderboard(period: period) { result in
            isLoading = false
            
            switch result {
            case .success(let response):
                self.leaderboardEntries = response.entries
                self.currentUserRank = response.current_user_rank
                self.periodInfo = (response.period_start, response.period_end)
                
            case .failure(let error):
                self.errorMessage = error.localizedDescription
                print("Leaderboard error: \(error)")
            }
        }
    }
    
    private func getPeriodDisplayText() -> String {
        if period == "weekly" {
            // Format dates
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            
            if let startDate = formatter.date(from: periodInfo.start),
               let endDate = formatter.date(from: periodInfo.end) {
                
                formatter.dateFormat = "MMM d"
                let startStr = formatter.string(from: startDate)
                let endStr = formatter.string(from: endDate)
                
                return "Week of \(startStr) - \(endStr)"
            }
            
            return "Weekly Ranking"
        } else {
            return "All-Time Ranking"
        }
    }
}

// MARK: - Leaderboard Row
struct LeaderboardRow: View {
    let entry: NetworkManager.LeaderboardEntry
    let isCurrentUser: Bool
    
    private let colors = ColorSystem.shared
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack {
            // Rank
            Text("\(entry.rank)")
                .font(.system(size: 16).weight(isCurrentUser ? .bold : .regular))
                .frame(width: 60, alignment: .center)
                .foregroundColor(isCurrentUser ? colors.accent : colors.primaryText(for: colorScheme))
            
            // Username
            Text(entry.username)
                .font(.system(size: 16).weight(isCurrentUser ? .bold : .regular))
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundColor(isCurrentUser ? colors.accent : colors.primaryText(for: colorScheme))
            
            // Score
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(entry.score)")
                    .font(.system(size: 16).weight(.bold))
                    .foregroundColor(isCurrentUser ? colors.accent : colors.primaryText(for: colorScheme))
                
                Text("\(entry.games_won)/\(entry.games_played) games")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .frame(width: 80, alignment: .trailing)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(
            isCurrentUser ?
                colors.accent.opacity(0.1) :
                Color.clear
        )
        .cornerRadius(8)
    }
}

// MARK: - Preview
struct LeaderboardView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            LeaderboardView()
                .preferredColorScheme(.light)
                .previewDisplayName("Light Mode")
            
            LeaderboardView()
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
        }
    }
}
