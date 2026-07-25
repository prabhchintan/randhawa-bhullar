import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var progress = YearProgress()

    var body: some View {
        VStack(spacing: 28) {
            DotGrid(progress: progress)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 6) {
                Text("\(progress.percent)%")
                    .font(.system(size: 48, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text("Day \(progress.dayOfYear) of \(progress.totalDays) · \(progress.daysRemaining) left")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        // Recompute whenever the app returns to the foreground, so the grid is
        // always current even if it was left open across midnight.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                progress = YearProgress()
            }
        }
    }
}

#Preview {
    ContentView()
}
