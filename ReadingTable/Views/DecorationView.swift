import SwiftUI

struct DecorationView: View {
    let decoration: Decoration
    var isSelected: Bool = false
    var isInteractive: Bool = true
    var onSelect: () -> Void = {}
    var onUpdate: (Double, Double, Double, Double) -> Void = { _, _, _, _ in }
    var onDelete: () -> Void = {}
    var onEditText: () -> Void = {}
    var onEditPhoto: () -> Void = {}
    var onStraighten: () -> Void = {}
    var onToggleClockStyle: () -> Void = {}

    @State private var dragOffset: CGSize = .zero
    @State private var showCalculatorSheet = false
    @State private var showRecordPlayerSheet = false
    @GestureState private var magnifyBy: CGFloat = 1.0
    @GestureState private var rotateBy: Angle = .zero

    private var visualSize: CGFloat { decoration.isStickyNote ? 110 : 70 }
    private var touchTargetSize: CGFloat {
        if decoration.isStickyNote { return 120 }
        if decoration.isPhotoFrame { return 160 }
        if decoration.isCalendar { return 150 }
        if decoration.isWeather { return 120 }
        if decoration.isClock { return 120 }
        if decoration.isLocation { return 120 }
        if decoration.isCalculator { return 110 }
        if decoration.isMusic { return 116 }
        return 88
    }

    /// The Polaroid frame artwork's transparent photo window, as a fraction of the whole image.
    private let photoWindowXFraction: CGFloat = 0.082
    private let photoWindowYFraction: CGFloat = 0.079
    private let photoWindowWidthFraction: CGFloat = 0.838
    private let photoWindowHeightFraction: CGFloat = 0.714
    private var photoFrameHeight: CGFloat { 140 }
    private var photoFrameWidth: CGFloat { photoFrameHeight * (1682.0 / 2033.0) }

    private var coverContent: some View {
        Group {
            if decoration.isStickyNote {
                let color = StickyNoteColor(rawValue: decoration.noteColorName ?? "") ?? .yellow
                RoundedRectangle(cornerRadius: 2)
                    .fill(color.color)
                    .overlay(
                        Text(decoration.noteText ?? "")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.black.opacity(0.75))
                            .multilineTextAlignment(.center)
                            .lineLimit(6)
                            .padding(10)
                    )
                    .frame(width: visualSize, height: visualSize)
                    .compositingGroup()
                    .shadow(color: .black.opacity(isSelected ? 0.35 : 0.28), radius: isSelected ? 9 : 6, x: 2, y: 4)
            } else if decoration.isPhotoFrame {
                ZStack(alignment: .topLeading) {
                    if let data = decoration.photoImageData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: photoFrameWidth * photoWindowWidthFraction, height: photoFrameHeight * photoWindowHeightFraction)
                            .clipped()
                            .offset(x: photoFrameWidth * photoWindowXFraction, y: photoFrameHeight * photoWindowYFraction)
                    }
                    Image("Decoration-PolaroidFrame")
                        .resizable()
                        .scaledToFit()
                        .frame(width: photoFrameWidth, height: photoFrameHeight)
                }
                .frame(width: photoFrameWidth, height: photoFrameHeight)
                .shadow(color: .black.opacity(isSelected ? 0.3 : 0.18), radius: isSelected ? 8 : 4, x: 2, y: 3)
            } else if decoration.isCalendar {
                CalendarDecorationContent()
                    .compositingGroup()
                    .shadow(color: .black.opacity(isSelected ? 0.32 : 0.22), radius: isSelected ? 9 : 5, x: 2, y: 4)
            } else if decoration.isWeather {
                WeatherDecorationContent()
                    .compositingGroup()
                    .shadow(color: .black.opacity(isSelected ? 0.32 : 0.22), radius: isSelected ? 9 : 5, x: 2, y: 4)
            } else if decoration.isClock {
                ClockDecorationContent(isAnalog: decoration.isAnalogClock)
                    .compositingGroup()
                    .shadow(color: .black.opacity(isSelected ? 0.32 : 0.22), radius: isSelected ? 9 : 5, x: 2, y: 4)
            } else if decoration.isLocation {
                LocationDecorationContent()
                    .compositingGroup()
                    .shadow(color: .black.opacity(isSelected ? 0.32 : 0.22), radius: isSelected ? 9 : 5, x: 2, y: 4)
            } else if decoration.isCalculator {
                CalculatorDecorationContent()
                    .compositingGroup()
                    .shadow(color: .black.opacity(isSelected ? 0.32 : 0.22), radius: isSelected ? 9 : 5, x: 2, y: 4)
            } else if decoration.isMusic {
                RecordPlayerDecorationContent()
                    .compositingGroup()
                    .shadow(color: .black.opacity(isSelected ? 0.32 : 0.22), radius: isSelected ? 9 : 5, x: 2, y: 4)
            } else {
                Image(decoration.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: visualSize, height: visualSize)
                    .shadow(color: .black.opacity(isSelected ? 0.3 : 0.18), radius: isSelected ? 8 : 4, x: 2, y: 3)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: isSelected ? 2 : 0)
        )
    }

    private var deleteButton: some View {
        Button(action: onDelete) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(.white)
                .background(Circle().fill(Color.black.opacity(0.6)).frame(width: 14, height: 14))
        }
        .offset(x: 6, y: -6)
    }

    private var editButton: some View {
        Button(action: decoration.isStickyNote ? onEditText : onEditPhoto) {
            Image(systemName: "pencil.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(.white)
                .background(Circle().fill(Color.black.opacity(0.6)).frame(width: 14, height: 14))
        }
        .offset(x: -6, y: -6)
    }

    private var clockStyleButton: some View {
        Button(action: onToggleClockStyle) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 16))
                .foregroundColor(.white)
                .background(Circle().fill(Color.black.opacity(0.6)).frame(width: 14, height: 14))
        }
        .offset(x: -6, y: -6)
    }

    private var openButton: some View {
        Button(action: {
            if decoration.isCalculator {
                showCalculatorSheet = true
            } else if decoration.isMusic {
                showRecordPlayerSheet = true
            }
        }) {
            Image(systemName: decoration.isCalculator ? "arrow.up.forward.app.fill" : "play.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(.white)
                .background(Circle().fill(Color.black.opacity(0.6)).frame(width: 14, height: 14))
        }
        .offset(x: -6, y: -6)
    }

    private var dragMagnifyRotateGesture: some Gesture {
        SimultaneousGesture(
            SimultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        let newX = decoration.x + value.translation.width
                        let newY = decoration.y + value.translation.height
                        dragOffset = .zero
                        onUpdate(newX, newY, decoration.scale, decoration.rotation)
                    },
                MagnificationGesture()
                    .updating($magnifyBy) { value, state, _ in
                        state = value
                    }
                    .onEnded { value in
                        let newScale = max(0.25, min(4.0, decoration.scale * value))
                        onUpdate(decoration.x, decoration.y, newScale, decoration.rotation)
                    }
            ),
            RotationGesture()
                .updating($rotateBy) { value, state, _ in
                    state = value
                }
                .onEnded { value in
                    let newRotation = decoration.rotation + value.degrees
                    onUpdate(decoration.x, decoration.y, decoration.scale, newRotation)
                }
        )
    }

    var body: some View {
        if isInteractive {
            coverContent
                .frame(width: touchTargetSize, height: touchTargetSize)
                .contentShape(Rectangle())
                .highPriorityGesture(
                    TapGesture(count: 2)
                        .onEnded {
                            onStraighten()
                        }
                        .exclusively(before: TapGesture(count: 1).onEnded {
                            onSelect()
                        })
                )
                .overlay(alignment: .topTrailing) {
                    if isSelected {
                        deleteButton
                    }
                }
                .overlay(alignment: .topLeading) {
                    if isSelected && (decoration.isStickyNote || decoration.isPhotoFrame) {
                        editButton
                    } else if isSelected && (decoration.isCalculator || decoration.isMusic) {
                        openButton
                    } else if isSelected && decoration.isClock {
                        clockStyleButton
                    }
                }
            .scaleEffect(decoration.scale * magnifyBy)
            .rotationEffect(.degrees(decoration.rotation + rotateBy.degrees))
            .position(x: decoration.x + dragOffset.width, y: decoration.y + dragOffset.height)
            .gesture(dragMagnifyRotateGesture)
            .sheet(isPresented: $showCalculatorSheet) {
                CalculatorSheetView()
            }
            .sheet(isPresented: $showRecordPlayerSheet) {
                RecordPlayerSheetView()
            }
        } else {
            coverContent
                .scaleEffect(decoration.scale)
                .rotationEffect(.degrees(decoration.rotation))
                .position(x: decoration.x, y: decoration.y)
        }
    }
}

private struct CalendarDecorationContent: View {
    @StateObject private var calendarService = CalendarService()
    @Environment(\.scenePhase) private var scenePhase

    private var weekday: String {
        Date().formatted(.dateTime.weekday(.abbreviated)).uppercased()
    }

    private var dayNumber: String {
        Date().formatted(.dateTime.day())
    }

    private var month: String {
        Date().formatted(.dateTime.month(.wide)).uppercased()
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(weekday)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(Color(red: 0.75, green: 0.24, blue: 0.22))

            VStack(spacing: 2) {
                Text(dayNumber)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.black.opacity(0.85))
                Text(month)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundColor(.black.opacity(0.5))
            }
            .padding(.top, 6)

            Divider().padding(.horizontal, 10).padding(.top, 6)

            VStack(alignment: .leading, spacing: 2) {
                if calendarService.accessDenied {
                    Text("Enable Calendar access in Settings")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                } else if calendarService.todaysEvents.isEmpty {
                    Text("No events today")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                } else {
                    ForEach(calendarService.todaysEvents.prefix(3)) { event in
                        Text(event.title)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.black.opacity(0.75))
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)

            Spacer(minLength: 0)
        }
        .frame(width: 110, height: 130)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .task {
            await calendarService.requestAccessAndFetchTodaysEvents()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await calendarService.requestAccessAndFetchTodaysEvents() }
            }
        }
    }
}

/// Weather exemplar (per DESIGN_REVIEW_LIVE_OBJECTS.md, following the approved Clock): a brass
/// desk barometer casing, matching TravelClockFace's material language, with the live reading
/// layered precisely on the dial instead of a generic white "--°" card.
private struct WeatherDecorationContent: View {
    @ObservedObject private var weatherService = WeatherService.shared
    @Environment(\.scenePhase) private var scenePhase

    private let brassLight = Color(red: 0.87, green: 0.73, blue: 0.4)
    private let brassDark = Color(red: 0.6, green: 0.46, blue: 0.19)
    private let inkColor = Color(red: 0.2, green: 0.16, blue: 0.1)

    var body: some View {
        ZStack {
            // Brass bezel
            Circle()
                .fill(AngularGradient(colors: [brassLight, brassDark, brassLight, brassDark, brassLight], center: .center))
                .frame(width: 86, height: 86)
            Circle()
                .stroke(brassDark.opacity(0.6), lineWidth: 1)
                .frame(width: 86, height: 86)

            // Dial face
            Circle()
                .fill(Color(red: 0.97, green: 0.94, blue: 0.86))
                .frame(width: 72, height: 72)

            ForEach(0..<8, id: \.self) { tick in
                Rectangle()
                    .fill(inkColor.opacity(0.3))
                    .frame(width: 1.5, height: 4)
                    .offset(y: -31)
                    .rotationEffect(.degrees(Double(tick) * 45))
            }

            dialContent

            // Little brass feet, grounding it as a tabletop instrument
            HStack(spacing: 48) {
                Capsule().fill(brassDark).frame(width: 8, height: 5)
                Capsule().fill(brassDark).frame(width: 8, height: 5)
            }
            .offset(y: 44)
        }
        .frame(width: 92, height: 96)
        .task {
            weatherService.requestLocationAndFetchWeather()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                weatherService.requestLocationAndFetchWeather()
            }
        }
    }

    @ViewBuilder
    private var dialContent: some View {
        if weatherService.accessDenied {
            VStack(spacing: 3) {
                Image(systemName: "location.slash")
                    .font(.system(size: 15))
                    .foregroundColor(inkColor.opacity(0.6))
                Text("Enable Location\nin Settings")
                    .font(.system(size: 7.5, weight: .medium))
                    .foregroundColor(inkColor.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            .frame(width: 58)
        } else if weatherService.isLoading {
            VStack(spacing: 3) {
                Image(systemName: "location.fill.viewfinder")
                    .font(.system(size: 15))
                    .foregroundColor(inkColor.opacity(0.5))
                Text("Reading the sky…")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(inkColor.opacity(0.5))
            }
        } else if weatherService.fetchFailed {
            VStack(spacing: 3) {
                Image(systemName: "exclamationmark.icloud")
                    .font(.system(size: 15))
                    .foregroundColor(inkColor.opacity(0.6))
                Text("Weather unavailable")
                    .font(.system(size: 7.5, weight: .medium))
                    .foregroundColor(inkColor.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            .frame(width: 58)
        } else {
            VStack(spacing: 2) {
                Image(systemName: weatherService.symbolName)
                    .font(.system(size: 20))
                    .symbolRenderingMode(.multicolor)
                Text(weatherService.temperature)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(inkColor)
                Text(weatherService.condition)
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundColor(inkColor.opacity(0.7))
                    .lineLimit(1)
            }
        }
    }
}

/// Clock exemplar per the 2026-08-08 design review (DESIGN_REVIEW_LIVE_OBJECTS.md):
/// a tactile physical-clock casing (drawn in SwiftUI, standing in for real Kate/Gigi
/// artwork until that's ready) with live hands/digits layered precisely on top.
private struct ClockDecorationContent: View {
    var isAnalog: Bool = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            if isAnalog {
                TravelClockFace(date: context.date)
            } else {
                DigitalClockFace(date: context.date)
            }
        }
    }
}

/// A small brass travel clock: circular bezel, cream dial, carrying ring.
private struct TravelClockFace: View {
    let date: Date

    private var components: DateComponents {
        Calendar.current.dateComponents([.hour, .minute, .second], from: date)
    }

    private var hourAngle: Angle {
        let hour = Double(components.hour ?? 0).truncatingRemainder(dividingBy: 12)
        let minute = Double(components.minute ?? 0)
        return .degrees((hour + minute / 60) * 30)
    }

    private var minuteAngle: Angle {
        .degrees(Double(components.minute ?? 0) * 6)
    }

    private var secondAngle: Angle {
        .degrees(Double(components.second ?? 0) * 6)
    }

    private let brassLight = Color(red: 0.87, green: 0.73, blue: 0.4)
    private let brassDark = Color(red: 0.6, green: 0.46, blue: 0.19)
    private let inkColor = Color(red: 0.2, green: 0.16, blue: 0.1)

    var body: some View {
        ZStack {
            // Carrying ring
            Circle()
                .trim(from: 0.1, to: 0.4)
                .stroke(brassDark, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: 20, height: 20)
                .rotationEffect(.degrees(90))
                .offset(y: -45)

            // Brass bezel
            Circle()
                .fill(AngularGradient(colors: [brassLight, brassDark, brassLight, brassDark, brassLight], center: .center))
                .frame(width: 86, height: 86)
            Circle()
                .stroke(brassDark.opacity(0.6), lineWidth: 1)
                .frame(width: 86, height: 86)

            // Dial face
            Circle()
                .fill(Color(red: 0.97, green: 0.94, blue: 0.86))
                .frame(width: 72, height: 72)

            ForEach(0..<12, id: \.self) { tick in
                Rectangle()
                    .fill(inkColor.opacity(tick % 3 == 0 ? 0.85 : 0.4))
                    .frame(width: tick % 3 == 0 ? 2.5 : 1.5, height: tick % 3 == 0 ? 8 : 4)
                    .offset(y: -31)
                    .rotationEffect(.degrees(Double(tick) * 30))
            }

            ClockHand(length: 17, width: 3, color: inkColor)
                .rotationEffect(hourAngle)
            ClockHand(length: 25, width: 2, color: inkColor)
                .rotationEffect(minuteAngle)
            ClockHand(length: 27, width: 1, color: Color(red: 0.72, green: 0.16, blue: 0.14))
                .rotationEffect(secondAngle)

            Circle()
                .fill(inkColor)
                .frame(width: 4, height: 4)
        }
        .frame(width: 92, height: 96)
    }
}

/// A softly glowing digital bedside clock: dark plastic casing, amber LED-style digits.
private struct DigitalClockFace: View {
    let date: Date

    /// Two-digit minutes always (fixes the earlier "18:3" truncation bug); hour stays
    /// locale-appropriate.
    private var timeText: String {
        date.formatted(.dateTime.hour().minute(.twoDigits))
    }

    private let caseTop = Color(red: 0.2, green: 0.18, blue: 0.16)
    private let caseBottom = Color(red: 0.09, green: 0.08, blue: 0.08)
    private let amber = Color(red: 1.0, green: 0.56, blue: 0.16)

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(LinearGradient(colors: [caseTop, caseBottom], startPoint: .top, endPoint: .bottom))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(colors: [Color.white.opacity(0.12), .clear], startPoint: .top, endPoint: .center))
                )
                .frame(width: 92, height: 62)

            Text(timeText)
                .font(.system(size: 21, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundColor(amber)
                .shadow(color: amber.opacity(0.75), radius: 4)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 4))

            HStack {
                Capsule().fill(Color.black.opacity(0.55)).frame(width: 10, height: 4)
                Spacer()
                Capsule().fill(Color.black.opacity(0.55)).frame(width: 10, height: 4)
            }
            .frame(width: 76)
            .offset(y: 33)
        }
        .frame(width: 96, height: 70)
    }
}

private struct ClockHand: View {
    let length: CGFloat
    let width: CGFloat
    let color: Color

    var body: some View {
        RoundedRectangle(cornerRadius: width / 2)
            .fill(color)
            .frame(width: width, height: length)
            .offset(y: -length / 2)
    }
}

private struct LocationDecorationContent: View {
    @StateObject private var locationService = LocationService()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 6) {
            if locationService.accessDenied {
                Image(systemName: "location.slash")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
                Text("Enable Location access in Settings")
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(Color(red: 0.85, green: 0.3, blue: 0.25))
                Text(locationService.placeName)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.black.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .padding(10)
        .frame(width: 100, height: 100)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .task {
            locationService.requestLocationAndFetchPlace()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                locationService.requestLocationAndFetchPlace()
            }
        }
    }
}

/// Calculator exemplar, matching DigitalClockFace's dark-plastic-and-amber material family
/// per the 2026-08-08 design review (DESIGN_REVIEW_LIVE_OBJECTS.md): a tactile pocket
/// calculator casing with an LED-style "0" readout and a grid of key caps, rather than a
/// generic white icon card.
private struct CalculatorDecorationContent: View {
    private let caseTop = Color(red: 0.2, green: 0.18, blue: 0.16)
    private let caseBottom = Color(red: 0.09, green: 0.08, blue: 0.08)
    private let amber = Color(red: 1.0, green: 0.56, blue: 0.16)

    var body: some View {
        VStack(spacing: 7) {
            Text("0")
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundColor(amber)
                .shadow(color: amber.opacity(0.75), radius: 3)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 3))

            VStack(spacing: 4) {
                ForEach(0..<4, id: \.self) { _ in
                    HStack(spacing: 4) {
                        ForEach(0..<4, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white.opacity(0.14))
                                .frame(height: 8)
                        }
                    }
                }
            }
        }
        .padding(8)
        .frame(width: 78, height: 92)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(LinearGradient(colors: [caseTop, caseBottom], startPoint: .top, endPoint: .bottom))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(LinearGradient(colors: [Color.white.opacity(0.12), .clear], startPoint: .top, endPoint: .center))
                )
        )
    }
}

/// Music exemplar, matching DigitalClockFace/CalculatorDecorationContent's dark-plastic-and-brass
/// material family per the 2026-08-08 design review (DESIGN_REVIEW_LIVE_OBJECTS.md): a small
/// portable record player, spinning a colored "album" label per track, rather than a generic
/// white music-note tile. Tapping the object (via the shared openButton) expands it into
/// RecordPlayerSheetView, the full player.
private struct RecordPlayerDecorationContent: View {
    @ObservedObject private var player = RecordPlayerService.shared

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !player.isPlaying)) { context in
            RecordPlayerCasing(track: player.currentTrack, isPlaying: player.isPlaying, now: context.date)
        }
    }
}

private struct RecordPlayerCasing: View {
    let track: RecordTrack
    let isPlaying: Bool
    let now: Date

    private let caseTop = Color(red: 0.2, green: 0.18, blue: 0.16)
    private let caseBottom = Color(red: 0.09, green: 0.08, blue: 0.08)
    private let brassLight = Color(red: 0.87, green: 0.73, blue: 0.4)
    private let brassDark = Color(red: 0.6, green: 0.46, blue: 0.19)

    /// Deriving the spin angle from a periodic `TimelineView` (rather than a started/stopped
    /// SwiftUI animation) means pausing is just "stop asking for new frames" — the disc freezes
    /// at whatever angle it was already at, with no snap-back or restart glitch.
    private var rotationDegrees: Double {
        let period = 2.6
        let seconds = now.timeIntervalSinceReferenceDate
        return (seconds.truncatingRemainder(dividingBy: period)) / period * 360
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(LinearGradient(colors: [caseTop, caseBottom], startPoint: .top, endPoint: .bottom))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(LinearGradient(colors: [Color.white.opacity(0.1), .clear], startPoint: .top, endPoint: .center))
                )
                .frame(width: 100, height: 88)

            VinylDiscView(track: track, diameter: 58)
                .rotationEffect(.degrees(rotationDegrees))
                .offset(x: -10, y: 3)

            RecordPlayerTonearm(brassLight: brassLight, brassDark: brassDark, isDown: isPlaying)
                .offset(x: 28, y: -16)
        }
        .frame(width: 110, height: 96)
    }
}

/// A small vinyl record whose center label is colored per-track, so switching tracks visibly
/// changes "the record on the platter" — the little-albums effect Adele and Kate asked for.
private struct VinylDiscView: View {
    let track: RecordTrack
    let diameter: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black)
                .frame(width: diameter, height: diameter)
            ForEach(1..<5, id: \.self) { ring in
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.6)
                    .frame(width: diameter * (0.4 + Double(ring) * 0.12))
            }
            Circle()
                .fill(
                    RadialGradient(
                        colors: [track.labelColor.opacity(0.9), track.labelColor],
                        center: .center, startRadius: 0, endRadius: diameter * 0.22
                    )
                )
                .frame(width: diameter * 0.44, height: diameter * 0.44)
            Circle()
                .fill(Color.black)
                .frame(width: diameter * 0.06, height: diameter * 0.06)
        }
    }
}

private struct RecordPlayerTonearm: View {
    let brassLight: Color
    let brassDark: Color
    let isDown: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            Circle()
                .fill(brassDark)
                .frame(width: 8, height: 8)
            RoundedRectangle(cornerRadius: 2)
                .fill(LinearGradient(colors: [brassLight, brassDark], startPoint: .leading, endPoint: .trailing))
                .frame(width: 32, height: 3)
                .offset(x: 4, y: 2.5)
                .rotationEffect(.degrees(isDown ? 26 : 4), anchor: .leading)
        }
        .animation(.easeInOut(duration: 0.4), value: isDown)
    }
}

struct CalculatorSheetView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var display: String = "0"
    @State private var storedValue: Double = 0
    @State private var pendingOperator: String? = nil
    @State private var isEnteringNewNumber = true

    private let buttonRows: [[String]] = [
        ["C", "±", "%", "÷"],
        ["7", "8", "9", "×"],
        ["4", "5", "6", "−"],
        ["1", "2", "3", "+"],
        ["0", ".", "="]
    ]

    private let caseTop = Color(red: 0.2, green: 0.18, blue: 0.16)
    private let caseBottom = Color(red: 0.09, green: 0.08, blue: 0.08)
    private let amber = Color(red: 1.0, green: 0.56, blue: 0.16)

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Spacer()
                Text(display)
                    .font(.system(size: 56, weight: .light, design: .monospaced))
                    .foregroundColor(amber)
                    .shadow(color: amber.opacity(0.65), radius: 6)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal, 24)

                ForEach(buttonRows, id: \.self) { row in
                    HStack(spacing: 10) {
                        ForEach(row, id: \.self) { symbol in
                            Button(action: { handleTap(symbol) }) {
                                Text(symbol)
                                    .font(.system(size: 26, weight: .medium, design: .rounded))
                                    .foregroundColor(foregroundColor(for: symbol))
                                    .frame(maxWidth: .infinity, minHeight: 60)
                                    .background(backgroundColor(for: symbol))
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                Spacer()
            }
            .background(
                LinearGradient(colors: [caseTop, caseBottom], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            )
            .navigationTitle("Calculator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(caseBottom, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .tint(amber)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func backgroundColor(for symbol: String) -> Color {
        if symbol == "C" || symbol == "±" || symbol == "%" { return Color.white.opacity(0.16) }
        if ["÷", "×", "−", "+", "="].contains(symbol) { return amber }
        return Color.white.opacity(0.08)
    }

    private func foregroundColor(for symbol: String) -> Color {
        if ["÷", "×", "−", "+", "="].contains(symbol) { return caseBottom }
        return .white
    }

    private func handleTap(_ symbol: String) {
        switch symbol {
        case "0"..."9":
            appendDigit(symbol)
        case ".":
            appendDecimal()
        case "C":
            clear()
        case "±":
            toggleSign()
        case "%":
            applyPercent()
        case "÷", "×", "−", "+":
            setPendingOperator(symbol)
        case "=":
            evaluate()
        default:
            break
        }
    }

    private func appendDigit(_ digit: String) {
        if isEnteringNewNumber || display == "0" {
            display = digit
            isEnteringNewNumber = false
        } else {
            display += digit
        }
    }

    private func appendDecimal() {
        if isEnteringNewNumber {
            display = "0."
            isEnteringNewNumber = false
        } else if !display.contains(".") {
            display += "."
        }
    }

    private func clear() {
        display = "0"
        storedValue = 0
        pendingOperator = nil
        isEnteringNewNumber = true
    }

    private func toggleSign() {
        if let value = Double(display) {
            display = formatted(-value)
        }
    }

    private func applyPercent() {
        if let value = Double(display) {
            display = formatted(value / 100)
        }
    }

    private func setPendingOperator(_ symbol: String) {
        if let pendingOperator, !isEnteringNewNumber {
            storedValue = compute(storedValue, currentDisplayValue, pendingOperator)
            display = formatted(storedValue)
        } else {
            storedValue = currentDisplayValue
        }
        pendingOperator = symbol
        isEnteringNewNumber = true
    }

    private func evaluate() {
        guard let pendingOperator else { return }
        storedValue = compute(storedValue, currentDisplayValue, pendingOperator)
        display = formatted(storedValue)
        self.pendingOperator = nil
        isEnteringNewNumber = true
    }

    private var currentDisplayValue: Double {
        Double(display) ?? 0
    }

    private func compute(_ lhs: Double, _ rhs: Double, _ operatorSymbol: String) -> Double {
        switch operatorSymbol {
        case "+": return lhs + rhs
        case "−": return lhs - rhs
        case "×": return lhs * rhs
        case "÷": return rhs == 0 ? 0 : lhs / rhs
        default: return rhs
        }
    }

    private func formatted(_ value: Double) -> String {
        if value == value.rounded() && abs(value) < 1e15 {
            return String(format: "%.0f", value)
        }
        return String(value)
    }
}

/// The full "little deck" record player, opened by tapping the tabletop turntable object.
/// Per DESIGN_REVIEW_LIVE_OBJECTS.md: "Opening Apple Music can remain a secondary action" —
/// the primary experience here is playing the bundled tracks directly.
struct RecordPlayerSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @ObservedObject private var player = RecordPlayerService.shared

    private let caseTop = Color(red: 0.2, green: 0.18, blue: 0.16)
    private let caseBottom = Color(red: 0.09, green: 0.08, blue: 0.08)
    private let amber = Color(red: 1.0, green: 0.56, blue: 0.16)

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer()

                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !player.isPlaying)) { context in
                    BigVinylDisc(track: player.currentTrack, now: context.date)
                }
                .frame(width: 220, height: 220)

                VStack(spacing: 4) {
                    Text(player.currentTrack.title)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    Text(player.currentTrack.artist)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }

                HStack(spacing: 36) {
                    Button(action: player.skipToPrevious) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    }
                    Button(action: player.togglePlayPause) {
                        Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 56))
                            .foregroundColor(amber)
                    }
                    Button(action: player.skipToNext) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    }
                }

                Button(action: {
                    if let url = URL(string: "https://music.apple.com") {
                        openURL(url)
                    }
                }) {
                    Text("Open in Apple Music")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.55))
                }
                .padding(.top, 4)

                Spacer()

                Text("Royalty-free lo-fi tracks, bundled with the app for offline listening.")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.3))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(colors: [caseTop, caseBottom], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            )
            .navigationTitle("Record Player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(caseBottom, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .tint(amber)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct BigVinylDisc: View {
    let track: RecordTrack
    let now: Date

    private var rotationDegrees: Double {
        let period = 3.2
        let seconds = now.timeIntervalSinceReferenceDate
        return (seconds.truncatingRemainder(dividingBy: period)) / period * 360
    }

    var body: some View {
        ZStack {
            Circle().fill(Color.black).frame(width: 220, height: 220)
            ForEach(1..<9, id: \.self) { ring in
                Circle()
                    .stroke(Color.white.opacity(0.05), lineWidth: 0.8)
                    .frame(width: 220 * (0.28 + Double(ring) * 0.08))
            }
            Circle()
                .fill(
                    RadialGradient(
                        colors: [track.labelColor.opacity(0.95), track.labelColor],
                        center: .center, startRadius: 0, endRadius: 46
                    )
                )
                .frame(width: 92, height: 92)
            VStack(spacing: 2) {
                Image(systemName: "music.note")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.85))
                Text(track.artist)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.75))
            }
            Circle().fill(Color.black).frame(width: 10, height: 10)
        }
        .rotationEffect(.degrees(rotationDegrees))
        .shadow(color: .black.opacity(0.5), radius: 20, y: 10)
    }
}

enum StickerPack: String, CaseIterable, Identifiable {
    case deskPlants = "Desk Plants"
    case coffeeHouse = "Coffee House"
    case fallDesk = "Fall Desk"

    var id: String { rawValue }

    var stickerNames: [String] {
        switch self {
        case .deskPlants:
            return [
                "Sticker-TFMSCactusGreenPot",
                "Sticker-TFMSFuzzyCacti",
                "Sticker-TFMSGreenPot",
                "Sticker-TFMSHangingPlant",
                "Sticker-TFMSPinkFlowerpot",
                "Sticker-TFMSPlantJar",
                "Sticker-TFMSSapling",
                "Sticker-TFMSSpikyPlant",
                "Sticker-TFMSSucculentClayPot",
                "Sticker-TFMSSucculentPot",
                "Sticker-TFMSSucculentWhite",
                "Sticker-TFMSTerrarium"
            ]
        case .coffeeHouse:
            return [
                "Sticker-TFMSBeansCup",
                "Sticker-TFMSBiscuitCup",
                "Sticker-TFMSBlackCoffee",
                "Sticker-TFMSCoffeeBean",
                "Sticker-TFMSCoffeeSign",
                "Sticker-TFMSColdCoffee",
                "Sticker-TFMSDusting",
                "Sticker-TFMSDustingFri",
                "Sticker-TFMSDustingMon",
                "Sticker-TFMSDustingSat",
                "Sticker-TFMSDustingSun",
                "Sticker-TFMSDustingThu",
                "Sticker-TFMSDustingTue",
                "Sticker-TFMSDustingWed",
                "Sticker-TFMSGreenCup",
                "Sticker-TFMSLeafArt",
                "Sticker-TFMSMasonJarCoffee",
                "Sticker-TFMSMustardCup",
                "Sticker-TFMSPaperCroissant",
                "Sticker-TFMSSugarPack",
                "Sticker-TFMSWhiteFroth"
            ]
        case .fallDesk:
            return [
                "Sticker-TFMSApplePie",
                "Sticker-TFMSAutumnDrink",
                "Sticker-TFMSBrownLeaf",
                "Sticker-TFMSCinnamonSticks",
                "Sticker-TFMSFoxCookie",
                "Sticker-TFMSLeafBook",
                "Sticker-TFMSLeafBook2",
                "Sticker-TFMSLeafDrink",
                "Sticker-TFMSOrangeGourd",
                "Sticker-TFMSPineconeAbove",
                "Sticker-TFMSPineconeSide",
                "Sticker-TFMSPumpkinSpiceDrink",
                "Sticker-TFMSRedLeaf",
                "Sticker-TFMSRedLeafTag",
                "Sticker-TFMSWhiteGourd",
                "Sticker-TFMSYellowLeaf"
            ]
        }
    }
}

struct StickyNoteEditorView: View {
    var existingText: String = ""
    var existingColor: StickyNoteColor = .yellow
    var onSave: (String, StickyNoteColor) -> Void

    @State private var text: String
    @State private var selectedColor: StickyNoteColor
    @Environment(\.dismiss) private var dismiss

    init(existingText: String = "", existingColor: StickyNoteColor = .yellow, onSave: @escaping (String, StickyNoteColor) -> Void) {
        self.existingText = existingText
        self.existingColor = existingColor
        self.onSave = onSave
        _text = State(initialValue: existingText)
        _selectedColor = State(initialValue: existingColor)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Note") {
                    TextEditor(text: $text)
                        .frame(minHeight: 120)
                }

                Section("Color") {
                    HStack(spacing: 16) {
                        ForEach(StickyNoteColor.allCases) { color in
                            Button(action: { selectedColor = color }) {
                                Circle()
                                    .fill(color.color)
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.accentColor, lineWidth: selectedColor == color ? 3 : 0)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle(existingText.isEmpty ? "New Sticky Note" : "Edit Sticky Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(text.trimmingCharacters(in: .whitespacesAndNewlines), selectedColor)
                        dismiss()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct StickerPickerView: View {
    var onPick: (String) -> Void

    @State private var selectedPack: StickerPack = .deskPlants
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(StickerPack.allCases) { pack in
                            Button(action: { selectedPack = pack }) {
                                Text(pack.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(selectedPack == pack ? Color(red: 0.1, green: 0.1, blue: 0.12) : Color(.systemGray6))
                                    .foregroundColor(selectedPack == pack ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }

                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 16)], spacing: 16) {
                        ForEach(selectedPack.stickerNames, id: \.self) { name in
                            Button(action: {
                                onPick(name)
                                dismiss()
                            }) {
                                Image(name)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 80, height: 80)
                                    .padding(8)
                                    .background(Color(.systemGray6))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Stickers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
