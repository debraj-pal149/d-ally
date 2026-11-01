import SwiftUI
import UIKit

// MARK: - Persistence / steps

enum DayCoachStep: Int, CaseIterable, Equatable {
    case addButton = 0
    case dayBody = 1
    case calendarTab = 2

    var progressLabel: String { "\(rawValue + 1) / \(Self.allCases.count)" }

    var title: String {
        switch self {
        case .addButton: AppCopy.coachAddTitle
        case .dayBody: AppCopy.coachDayTitle
        case .calendarTab: AppCopy.coachCalendarTitle
        }
    }

    var body: String {
        switch self {
        case .addButton: AppCopy.coachAddBody
        case .dayBody: AppCopy.coachDayBody
        case .calendarTab: AppCopy.coachCalendarBody
        }
    }

    var cta: String {
        self == .calendarTab ? AppCopy.coachDone : AppCopy.coachNext
    }

    var next: DayCoachStep? {
        DayCoachStep(rawValue: rawValue + 1)
    }
}

enum DayCoach {
    /// Set when Profile setup finishes or Settings → Show welcome again.
    /// Cleared when the Day spotlight tour finishes or is dismissed.
    static var isPending: Bool {
        get { UserDefaults.standard.bool(forKey: AppStorageKey.dayCoachPending) }
        set { UserDefaults.standard.set(newValue, forKey: AppStorageKey.dayCoachPending) }
    }

    static func markPending() {
        isPending = true
    }

    static func clearPending() {
        isPending = false
    }
}

// MARK: - Anchors (store — PreferenceKey does not reliably cross TabView)

enum CoachAnchorID: Hashable {
    case addButton
    case dayBody
    case calendarTab
}

@Observable
final class CoachAnchorStore {
    var frames: [CoachAnchorID: CGRect] = [:]

    func set(_ id: CoachAnchorID, _ rect: CGRect) {
        // Ignore zero frames from offscreen / unloaded tabs.
        guard rect.width > 1, rect.height > 1 else { return }
        if frames[id] != rect {
            frames[id] = rect
        }
    }
}

private struct CoachAnchorStoreKey: EnvironmentKey {
    static let defaultValue = CoachAnchorStore()
}

private struct CoachHidesAddButtonKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var coachAnchors: CoachAnchorStore {
        get { self[CoachAnchorStoreKey.self] }
        set { self[CoachAnchorStoreKey.self] = newValue }
    }

    /// When true, DayPagerView hides the real + so the lit coach stand-in is the only one visible.
    var coachHidesAddButton: Bool {
        get { self[CoachHidesAddButtonKey.self] }
        set { self[CoachHidesAddButtonKey.self] = newValue }
    }
}

extension View {
    /// Publishes this view’s frame in the named coach coordinate space.
    func coachAnchor(_ id: CoachAnchorID, padding: CGFloat = 6) -> some View {
        modifier(CoachAnchorReporter(id: id, padding: padding))
    }
}

private struct CoachAnchorReporter: ViewModifier {
    var id: CoachAnchorID
    var padding: CGFloat
    @Environment(\.coachAnchors) private var store

    func body(content: Content) -> some View {
        content.background {
            GeometryReader { geo in
                // Global frames — overlay converts with its GeometryReader origin
                // (same path as Calendar tab frames; named-space was drifting for the FAB).
                let rect = geo.frame(in: .global).insetBy(dx: -padding, dy: -padding)
                Color.clear
                    .onAppear { store.set(id, rect) }
                    .onChange(of: rect) { _, new in store.set(id, new) }
            }
        }
    }
}

// MARK: - Overlay

struct DayCoachOverlay: View {
    static let spaceName = "dallyCoachSpace"

    @Binding var step: DayCoachStep
    var anchors: [CoachAnchorID: CGRect]
    var tabBarFrames: [CGRect]
    var onFinish: () -> Void
    /// Runs the real control for this step (+ / day CTA / Calendar), then advances.
    var onHighlightActivate: (DayCoachStep) -> Void

    /// White card width only (caret sits outside this for layout math).
    private let tipCardWidth: CGFloat = 272
    private let caretHeight: CGFloat = 10
    @State private var tipCardHeight: CGFloat = 132

    private var tipBubbleHeight: CGFloat { tipCardHeight + caretHeight }

    var body: some View {
        GeometryReader { geo in
            let canvas = geo.size
            // Everything (FAB prefs, UIKit tabs) is global → local via this origin.
            let coachOrigin = geo.frame(in: .global).origin
            let local: (CGRect) -> CGRect = { r in
                CGRect(
                    x: r.minX - coachOrigin.x,
                    y: r.minY - coachOrigin.y,
                    width: r.width,
                    height: r.height
                )
            }
            let localAnchors = anchors.mapValues(local)
            let localTabs = tabBarFrames.map(local)
            let addHole = Self.addButtonHole(localTabs: localTabs, canvas: canvas, measured: localAnchors[.addButton])
            let calendarHole = Self.calendarHole(localTabs: localTabs, canvas: canvas)
            Group {
                if step == .dayBody {
                    dayBodyCoach(canvas: canvas)
                } else if step == .addButton {
                    addButtonCoach(canvas: canvas, coachOrigin: coachOrigin)
                } else {
                    cutoutCoach(
                        canvas: canvas,
                        addHole: addHole,
                        calendarHole: calendarHole
                    )
                }
            }
        }
        .ignoresSafeArea()
        .transition(.opacity)
        .accessibilityAddTraits(.isModal)
    }

    /// + coach: pin tip + lit FAB with the same trailing/bottom padding as DayPagerView
    /// so the stand-in sits on the real button (absolute global frames were drifting).
    private func addButtonCoach(canvas: CGSize, coachOrigin: CGPoint) -> some View {
        let side: CGFloat = 56
        let trailing: CGFloat = 20
        let gapAboveTab: CGFloat = 20
        // UITabBar top ≈ Day content bottom (button frames sit lower in a floating bar).
        let tabTop: CGFloat = {
            if let bar = TabBarFrameReader.barFrame() {
                return bar.minY - coachOrigin.y
            }
            if let first = tabBarFrames.first {
                return first.minY - coachOrigin.y
            }
            return canvas.height - 83
        }()
        // Real FAB bottom = tabBar.top - 20 → pad from overlay bottom.
        let bottomPad = max(canvas.height - tabTop + gapAboveTab, gapAboveTab + 49)
        // Caret tip (caretX + 9) sits on the FAB midX within the trailing-aligned stack.
        let caretX = tipCardWidth - side / 2 - 9 + 2

        // Dim as .background so it cannot paint above the lit FAB (ignoresSafeArea
        // on a ZStack Color sibling was covering the stand-in).
        return VStack(alignment: .trailing, spacing: 12) {
            tipBubble(caret: .down, caretX: caretX)

            Button(action: activateHighlight) {
                Circle()
                    .fill(AppColors.aqua)
                    .frame(width: side, height: side)
                    .overlay {
                        Image(systemName: "plus")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Color(hex: "#102026"))
                    }
                    .overlay {
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.95), AppColors.aqua.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 2.5, dash: [6, 4])
                            )
                    }
                    .shadow(color: AppColors.aqua.opacity(0.55), radius: 14, y: 4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(highlightAccessibilityLabel)
        }
        .padding(.trailing, trailing)
        .padding(.bottom, bottomPad)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .background(Color.black.opacity(0.72).ignoresSafeArea())
    }

    /// Prefer the measured 56pt circle; fall back to trailing/bottom math above the tab bar.
    private static func addButtonHole(localTabs: [CGRect], canvas: CGSize, measured: CGRect?) -> CGRect {
        let side: CGFloat = 56
        let trailing: CGFloat = 20
        let gapAboveTab: CGFloat = 20
        if let tabTop = localTabs.map(\.minY).min() {
            return CGRect(
                x: canvas.width - trailing - side,
                y: tabTop - gapAboveTab - side,
                width: side,
                height: side
            )
        }
        if let measured, measured.width > 40, measured.height > 40,
           measured.midX > canvas.width * 0.55, measured.midY > canvas.height * 0.55 {
            return CGRect(
                x: measured.midX - side / 2,
                y: measured.midY - side / 2,
                width: side,
                height: side
            )
        }
        return CGRect(
            x: canvas.width - trailing - side,
            y: canvas.height - 120 - side,
            width: side,
            height: side
        )
    }

    private static func calendarHole(localTabs: [CGRect], canvas: CGSize) -> CGRect? {
        // Index 1 = Calendar in Day / Calendar / Profile / Settings.
        if localTabs.count >= 2 {
            return localTabs[1].insetBy(dx: -1, dy: -1)
        }
        let w = canvas.width / 4
        return CGRect(x: w + 4, y: canvas.height - 56, width: w - 8, height: 48)
    }

    /// Step 2: full dim (no hole) so real habits never show; sample rows + tip stacked.
    private func dayBodyCoach(canvas: CGSize) -> some View {
        ZStack {
            Color.black.opacity(0.82)
                .ignoresSafeArea()
                .allowsHitTesting(true)

            VStack(spacing: 10) {
                Spacer()
                    .frame(height: sampleTopInset(canvas: canvas))

                DayCoachSampleDayView()
                    .padding(.horizontal, 16)
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [AppColors.aqua, AppColors.aqua.opacity(0.4)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 2, dash: [7, 5])
                            )
                            .padding(.horizontal, 16)
                            .allowsHitTesting(false)
                            .shadow(color: AppColors.aqua.opacity(0.35), radius: 10)
                    }
                    .onTapGesture(perform: activateHighlight)

                tipBubble(caret: .up, caretX: tipCardWidth / 2 - 9)
                    .padding(.horizontal, 16)

                Spacer(minLength: 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    /// Steps 1 and 3: full dim + full-brightness stand-in on the target
    /// (clear-hole compositing was not revealing controls under the overlay).
    private func cutoutCoach(
        canvas: CGSize,
        addHole: CGRect,
        calendarHole: CGRect?
    ) -> some View {
        let holeRect = resolvedHole(in: canvas, addHole: addHole, calendarHole: calendarHole)
        let layout = tipLayout(hole: holeRect, canvas: canvas)
        let radius = holeRect.map { cornerRadius(for: $0) } ?? 16

        return ZStack {
            if let holeRect {
                Button(action: activateHighlight) {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(Color.white.opacity(0.001))
                }
                .buttonStyle(.plain)
                .frame(width: max(holeRect.width, 56), height: max(holeRect.height, 56))
                .position(x: holeRect.midX, y: holeRect.midY)
                .accessibilityLabel(highlightAccessibilityLabel)

                litTarget(at: holeRect)
                    .allowsHitTesting(false)

                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.95), AppColors.aqua.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 2.5, dash: [6, 4])
                    )
                    .frame(width: holeRect.width, height: holeRect.height)
                    .position(x: holeRect.midX, y: holeRect.midY)
                    .allowsHitTesting(false)
                    .shadow(color: AppColors.aqua.opacity(0.5), radius: 14)
            }

            tipBubble(caret: layout.caret, caretX: layout.caretX)
                .position(x: layout.center.x, y: layout.center.y)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.72).ignoresSafeArea())
    }

    @ViewBuilder
    private func litTarget(at hole: CGRect) -> some View {
        switch step {
        case .addButton:
            Circle()
                .fill(AppColors.aqua)
                .frame(width: 56, height: 56)
                .overlay {
                    Image(systemName: "plus")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color(hex: "#102026"))
                }
                .shadow(color: AppColors.aqua.opacity(0.45), radius: 12, y: 4)
                .position(x: hole.midX, y: hole.midY)
        case .calendarTab:
            VStack(spacing: 2) {
                Image(systemName: "calendar")
                    .font(.system(size: 22, weight: .semibold))
                Text("Calendar")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(AppColors.aqua)
            .frame(width: max(hole.width, 64), height: max(hole.height, 48))
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(hex: "#1C1C1E"))
                    .shadow(color: AppColors.aqua.opacity(0.35), radius: 10)
            )
            .position(x: hole.midX, y: hole.midY)
        case .dayBody:
            EmptyView()
        }
    }

    private func tipBubble(caret: TipCaret, caretX: CGFloat) -> some View {
        VStack(spacing: 0) {
            if caret == .up {
                caretShape
                    .frame(width: 18, height: caretHeight)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, caretX)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    Text(step.progressLabel)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.aqua)
                        .tracking(0.6)
                    Spacer(minLength: 0)
                    Button(action: finish) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color(hex: "#8E8E93"))
                            .frame(width: 28, height: 28)
                            .background(Color(hex: "#F2F2F7"), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                }

                Text(step.title)
                    .font(AppTypography.taskName)
                    .foregroundStyle(Color(hex: "#1C1C1E"))
                    .fixedSize(horizontal: false, vertical: true)

                Text(step.body)
                    .font(AppTypography.footnote)
                    .foregroundStyle(Color(hex: "#6C6C70"))
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Spacer(minLength: 0)
                    Button(action: advance) {
                        Text(step.cta)
                            .font(AppTypography.button)
                            .foregroundStyle(Color(hex: "#F2F2F7"))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(Color(hex: "#1C1C1E"), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .frame(width: tipCardWidth, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.28), radius: 22, y: 10)
            )
            .background {
                GeometryReader { g in
                    Color.clear
                        .onAppear { tipCardHeight = g.size.height }
                        .onChange(of: g.size.height) { _, h in tipCardHeight = h }
                }
            }

            if caret == .down {
                caretShape
                    .rotationEffect(.degrees(180))
                    .frame(width: 18, height: caretHeight)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, caretX)
            }
        }
        .frame(width: tipCardWidth)
    }

    private var caretShape: some View {
        CoachCaret()
            .fill(Color.white)
            .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
    }

    private var highlightAccessibilityLabel: String {
        switch step {
        case .addButton: AppCopy.addDailyReminder
        case .dayBody: AppCopy.coachDayTitle
        case .calendarTab: "Calendar"
        }
    }

    private func activateHighlight() {
        onHighlightActivate(step)
        advance()
    }

    private func advance() {
        Haptics.selection()
        if let next = step.next {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                step = next
            }
        } else {
            finish()
        }
    }

    private func finish() {
        Haptics.selection()
        onFinish()
    }

    private func resolvedHole(
        in size: CGSize,
        addHole: CGRect,
        calendarHole: CGRect?
    ) -> CGRect? {
        let canvas = CGRect(origin: .zero, size: size)
        let candidate: CGRect? = {
            switch step {
            case .addButton:
                return addHole
            case .dayBody:
                return nil
            case .calendarTab:
                return calendarHole
            }
        }()
        if let hole = candidate, hole.width > 4, hole.height > 4 {
            let clipped = hole.standardized.intersection(canvas)
            if clipped.width > 4, clipped.height > 4 { return clipped }
            // Hole may sit partly in the home-indicator band; keep unclipped so
            // Canvas can still clear that region.
            if canvas.intersects(hole) { return hole }
        }
        switch step {
        case .addButton:
            return addHole
        case .dayBody:
            return nil
        case .calendarTab:
            return Self.calendarHole(localTabs: [], canvas: size)
        }
    }

    private func cornerRadius(for hole: CGRect) -> CGFloat {
        switch step {
        case .addButton: return min(hole.width, hole.height) / 2
        case .calendarTab: return 12
        case .dayBody: return 22
        }
    }

    /// Sit the sample under the Day header (“Today”), with room for the tip below.
    private func sampleTopInset(canvas: CGSize) -> CGFloat {
        // Safe area + “Today” header; keep sample high so tip fits underneath on small phones.
        min(112, max(72, canvas.height * 0.12))
    }

    /// Tip center + caret so `.position` places the bubble with the caret on the hole midX.
    private func tipLayout(hole: CGRect?, canvas: CGSize) -> (center: CGPoint, caret: TipCaret, caretX: CGFloat) {
        let margin: CGFloat = 16
        let gap: CGFloat = 10
        let tipW = tipCardWidth
        let tipH = max(tipBubbleHeight, 140)
        let holeRect = hole ?? CGRect(x: canvas.width / 2, y: canvas.height / 2, width: 1, height: 1)

        // + and Calendar sit low — tip always prefers above them.
        let preferAbove = (step == .addButton || step == .calendarTab)
        let roomAbove = holeRect.minY - margin
        let roomBelow = canvas.height - holeRect.maxY - margin
        let placeAbove: Bool = {
            if preferAbove, roomAbove >= tipH + gap { return true }
            if !preferAbove, roomBelow >= tipH + gap { return false }
            if roomAbove >= tipH + gap { return true }
            if roomBelow >= tipH + gap { return false }
            return roomAbove >= roomBelow
        }()

        let caret: TipCaret = placeAbove ? .down : .up

        // Horizontal: Calendar centered on tab; + tip sits left so it does not cover the FAB.
        var originX: CGFloat
        switch step {
        case .addButton:
            originX = holeRect.maxX - tipW + 4
        case .calendarTab, .dayBody:
            originX = holeRect.midX - tipW / 2
        }
        originX = min(max(originX, margin), canvas.width - tipW - margin)

        var originY: CGFloat
        if placeAbove {
            originY = holeRect.minY - gap - tipH
        } else {
            originY = holeRect.maxY + gap
        }
        originY = min(max(originY, margin), canvas.height - tipH - margin)

        // Caret leading inset so the caret tip sits on hole.midX.
        let caretX = min(max(holeRect.midX - originX - 9, 8), tipW - 26)

        return (
            CGPoint(x: originX + tipW / 2, y: originY + tipH / 2),
            caret,
            caretX
        )
    }
}

private enum TipCaret {
    case up
    case down
}

private struct CoachCaret: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Sample list matching real `TaskRowView` chrome (color rail, dot, chips, circle) — coach step 2 only.
struct DayCoachSampleDayView: View {
    @Environment(\.colorScheme) private var scheme

    private let plant = Color(hex: "#2CD4FF")
    private let exercise = Color(hex: "#FF6C55")
    private let walk = Color(hex: "#37E3AF")

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            DaySectionHeader(title: "Later today")
            sampleRow(
                name: "Water outside plant",
                time: "8:00 AM",
                color: plant,
                chip: ("Past due", AppColors.warning),
                status: nil
            )
            sampleRow(
                name: "Exercise",
                time: "by 10:00 PM",
                color: exercise,
                chip: ("Until 10:00 PM", AppColors.textTertiary(scheme)),
                status: nil
            )
            sampleRow(
                name: "Walk",
                time: "by 10:00 PM",
                color: walk,
                chip: ("Until 10:00 PM", AppColors.textTertiary(scheme)),
                status: nil
            )
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(scheme == .dark ? Color(hex: "#12161C") : Color(hex: "#F2F5F7"))
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Sample day. Water outside plant, Exercise, Walk.")
    }

    private func sampleRow(
        name: String,
        time: String,
        color: Color,
        chip: (String, Color),
        status: DayLogStatus?
    ) -> some View {
        HStack(alignment: .center, spacing: 0) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color)
                .frame(width: 4)
                .padding(.vertical, 10)

            HStack(alignment: .center, spacing: 12) {
                Circle()
                    .fill(color)
                    .frame(width: 12, height: 12)

                VStack(alignment: .leading, spacing: 3) {
                    Text(name)
                        .font(AppTypography.taskName)
                        .foregroundStyle(AppColors.textPrimary(scheme))
                        .lineLimit(1)
                    DayStatusChip(text: chip.0, tint: chip.1)
                }

                Spacer(minLength: 8)

                Text(time)
                    .font(AppTypography.time.monospacedDigit())
                    .foregroundStyle(AppColors.textSecondary(scheme))

                ConfirmDoneButton(color: color, status: status, enabled: false, action: {})
            }
            .padding(.leading, 10)
            .padding(.vertical, 11)
            .padding(.trailing, 12)
        }
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColors.rowFill(scheme))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(color.opacity(scheme == .dark ? 0.28 : 0.22), lineWidth: 1)
                }
        }
    }
}

// MARK: - Tab bar frames (Calendar = index 1)

enum TabBarFrameReader {
    /// Global frame of the UITabBar itself (top ≈ day content bottom).
    static func barFrame() -> CGRect? {
        guard let window = activeWindow, let tabBar = findTabBar(in: window) else { return nil }
        return tabBar.convert(tabBar.bounds, to: nil)
    }

    /// Global (screen) frames for UITabBar buttons, sorted left → right.
    static func buttonFrames() -> [CGRect] {
        guard let window = activeWindow, let tabBar = findTabBar(in: window) else { return [] }
        let buttons = tabBarButtons(in: tabBar)
        if !buttons.isEmpty {
            return buttons.map { $0.convert($0.bounds, to: nil) }
        }
        // Fallback: equal slices of the tab bar.
        let bar = tabBar.convert(tabBar.bounds, to: nil)
        let count = max(tabBar.items?.count ?? 4, 1)
        let w = bar.width / CGFloat(count)
        return (0..<count).map { i in
            CGRect(x: bar.minX + CGFloat(i) * w, y: bar.minY, width: w, height: bar.height)
        }
    }

    /// Prefer the control whose accessibility label matches (e.g. "Calendar").
    static func frame(labeled label: String) -> CGRect? {
        guard let window = activeWindow, let tabBar = findTabBar(in: window) else { return nil }
        let buttons = tabBarButtons(in: tabBar)
        let match = buttons.first {
            let a = ($0.accessibilityLabel ?? "").localizedCaseInsensitiveContains(label)
            let b = ($0.accessibilityIdentifier ?? "").localizedCaseInsensitiveContains(label)
            return a || b
        }
        return match.map { $0.convert($0.bounds, to: nil) }
    }

    private static func tabBarButtons(in tabBar: UITabBar) -> [UIView] {
        // Walk deeply — liquid-glass / newer tab bars nest buttons.
        var found: [UIView] = []
        func walk(_ view: UIView) {
            let name = String(describing: type(of: view))
            if name.contains("UITabBarButton") || name.contains("TabBarButton") {
                found.append(view)
                return
            }
            for child in view.subviews { walk(child) }
        }
        walk(tabBar)
        return found.sorted { $0.frame.minX < $1.frame.minX }
    }

    private static var activeWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
    }

    private static func findTabBar(in view: UIView) -> UITabBar? {
        if let tab = view as? UITabBar { return tab }
        for child in view.subviews {
            if let tab = findTabBar(in: child) { return tab }
        }
        return nil
    }
}

/// Hosts the coach after onboarding. Owns pending flag + step state.
struct DayCoachHostModifier: ViewModifier {
    @Environment(DeepLinkRouter.self) private var router
    @AppStorage(AppStorageKey.dayCoachPending) private var dayCoachPending = false
    @State private var step: DayCoachStep = .addButton
    @State private var store = CoachAnchorStore()
    @State private var tabFrames: [CGRect] = []
    @State private var active = false

    func body(content: Content) -> some View {
        content
            .environment(\.coachAnchors, store)
            .environment(\.coachHidesAddButton, active && step == .addButton)
            .coordinateSpace(name: DayCoachOverlay.spaceName)
            .overlay {
                if active {
                    DayCoachOverlay(
                        step: $step,
                        anchors: store.frames,
                        // Global frames — overlay converts with its own GeometryReader origin.
                        tabBarFrames: tabFrames,
                        onFinish: dismiss,
                        onHighlightActivate: activateHighlight
                    )
                    .zIndex(1000)
                }
            }
            .onAppear {
                considerStarting()
                #if DEBUG
                DebugCoachAdvance.install()
                #endif
            }
            #if DEBUG
            .onReceive(NotificationCenter.default.publisher(for: .dallyDebugCoachAdvance)) { _ in
                guard active else { return }
                if let next = step.next {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                        step = next
                    }
                } else {
                    dismiss()
                }
            }
            #endif
            .onChange(of: dayCoachPending) { _, pending in
                if pending { considerStarting() }
            }
            .onChange(of: step) { _, new in
                refreshTabFrames()
                if new == .calendarTab {
                    // Tab bar can settle a beat after the step change.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        refreshTabFrames()
                    }
                }
            }
    }

    private func considerStarting() {
        guard dayCoachPending, !active else { return }
        // Land on Day / today so anchors match the tips.
        router.selectedTab = .day
        router.selectedDay = Date().startOfLocalDay
        step = .addButton
        refreshTabFrames()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            refreshTabFrames()
            withAnimation(.easeOut(duration: 0.28)) { active = true }
            Analytics.track("day_coach_started")
        }
    }

    private func dismiss() {
        withAnimation(.easeIn(duration: 0.2)) { active = false }
        dayCoachPending = false
        Analytics.track("day_coach_completed", ["step": String(step.rawValue)])
    }

    private func activateHighlight(_ step: DayCoachStep) {
        switch step {
        case .addButton, .dayBody:
            router.openEditor(taskId: nil)
        case .calendarTab:
            router.selectedTab = .calendar
        }
        Analytics.track("day_coach_highlight_tapped", ["step": String(step.rawValue)])
    }

    private func refreshTabFrames() {
        // Prefer label match for Calendar so index drift cannot mis-aim the tip.
        var frames = TabBarFrameReader.buttonFrames()
        if let calendar = TabBarFrameReader.frame(labeled: "Calendar"), frames.count >= 2 {
            frames[1] = calendar
        }
        tabFrames = frames
        // Only fill FAB from UIKit when SwiftUI has not reported it yet.
        if store.frames[.addButton] == nil,
           let add = AccessibilityFrameReader.frame(identifier: "coach.addButton") {
            store.set(.addButton, add)
        }
    }
}

/// Finds a view by accessibility identifier and returns a tight global frame.
enum AccessibilityFrameReader {
    static func frame(identifier: String) -> CGRect? {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows)
            .first(where: \.isKeyWindow),
              let view = find(in: window, identifier: identifier) else { return nil }
        let global = view.convert(view.bounds, to: nil)
        let side = min(max(min(global.width, global.height), 52), 64)
        return CGRect(
            x: global.midX - side / 2,
            y: global.midY - side / 2,
            width: side,
            height: side
        )
    }

    private static func find(in view: UIView, identifier: String) -> UIView? {
        if view.accessibilityIdentifier == identifier { return view }
        for child in view.subviews {
            if let hit = find(in: child, identifier: identifier) { return hit }
        }
        return nil
    }
}

extension View {
    func dayCoachHost() -> some View {
        modifier(DayCoachHostModifier())
    }
}
