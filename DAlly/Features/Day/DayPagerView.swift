import SwiftUI

struct DayPagerView: View {
    @Environment(DeepLinkRouter.self) private var router
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        @Bindable var router = router
        ZStack(alignment: .bottomTrailing) {
            AppCanvas()
            VStack(spacing: 0) {
                DayHeaderView(
                    day: router.selectedDay,
                    onPrevious: { shift(-1) },
                    onNext: { shift(1) },
                    onJumpToday: {
                        Haptics.dayChange()
                        router.jumpToToday()
                    }
                )
                // Single day view — the old 3-page TabView jumped selectedDay when
                // @Query/animations refreshed after marking a past day done.
                DayView(day: router.selectedDay)
                    .id(router.selectedDay.localDayKey)
                    .transition(.opacity)
                    .simultaneousGesture(daySwipeGesture)
            }
            Button {
                router.openEditor(taskId: nil)
            } label: {
                Image(systemName: "plus")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color(hex: "#102026"))
                    .frame(width: 56, height: 56)
                    .background(AppColors.aqua, in: Circle())
                    .shadow(color: AppColors.aqua.opacity(0.45), radius: 12, y: 4)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 20)
            .padding(.bottom, 20)
            .accessibilityLabel(AppCopy.addDailyReminder)
        }
    }

    private var daySwipeGesture: some Gesture {
        DragGesture(minimumDistance: 40)
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height
                guard abs(dx) > abs(dy) * 1.6, abs(dx) > 60 else { return }
                if dx > 0 {
                    shift(-1)
                } else {
                    shift(1)
                }
            }
    }

    private func shift(_ days: Int) {
        Haptics.dayChange()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
            router.selectedDay = router.selectedDay.addingLocalDays(days)
        }
    }
}
