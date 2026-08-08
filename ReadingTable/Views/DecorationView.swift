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
    @GestureState private var magnifyBy: CGFloat = 1.0
    @GestureState private var rotateBy: Angle = .zero
    @Environment(\.openURL) private var openURL

    private var visualSize: CGFloat { decoration.isStickyNote ? 110 : 70 }
    private var touchTargetSize: CGFloat {
        if decoration.isStickyNote { return 120 }
        if decoration.isPhotoFrame { return 160 }
        if decoration.isCalendar { return 150 }
        if decoration.isWeather { return 120 }
        if decoration.isClock { return 120 }
        if decoration.isLocation { return 120 }
        if decoration.isCalculator { return 110 }
        if decoration.isMusic { return 100 }
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
                MusicDecorationContent()
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
                if let url = URL(string: "https://music.apple.com") {
                    openURL(url)
                }
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

private struct WeatherDecorationContent: View {
    @StateObject private var weatherService = WeatherService()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 6) {
            if weatherService.accessDenied {
                Image(systemName: "location.slash")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
                Text("Enable Location access in Settings")
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Image(systemName: weatherService.symbolName)
                    .font(.system(size: 28))
                    .symbolRenderingMode(.multicolor)
                Text(weatherService.temperature)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(.black.opacity(0.85))
                Text(weatherService.condition)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.black.opacity(0.6))
                    .lineLimit(1)
            }
        }
        .padding(10)
        .frame(width: 100, height: 100)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .task {
            weatherService.requestLocationAndFetchWeather()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                weatherService.requestLocationAndFetchWeather()
            }
        }
    }
}

private struct ClockDecorationContent: View {
    var isAnalog: Bool = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Group {
                if isAnalog {
                    AnalogClockFace(date: context.date)
                        .frame(width: 76, height: 76)
                } else {
                    Text(context.date.formatted(.dateTime.hour().minute()))
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundColor(.black.opacity(0.85))
                        .monospacedDigit()
                }
            }
            .padding(10)
            .frame(width: 100, height: 100)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}

private struct AnalogClockFace: View {
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

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.black.opacity(0.8), lineWidth: 2.5)
            ForEach(0..<12) { tick in
                Rectangle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 2, height: tick % 3 == 0 ? 7 : 4)
                    .offset(y: -34)
                    .rotationEffect(.degrees(Double(tick) * 30))
            }
            ClockHand(length: 20, width: 3, color: .black.opacity(0.85))
                .rotationEffect(hourAngle)
            ClockHand(length: 28, width: 2, color: .black.opacity(0.85))
                .rotationEffect(minuteAngle)
            ClockHand(length: 30, width: 1, color: .red)
                .rotationEffect(secondAngle)
            Circle()
                .fill(Color.black.opacity(0.85))
                .frame(width: 5, height: 5)
        }
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

private struct CalculatorDecorationContent: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "divide.square.fill")
                .font(.system(size: 26))
                .foregroundColor(Color(red: 0.2, green: 0.55, blue: 0.45))
            Text("Calculator")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.black.opacity(0.6))
        }
        .frame(width: 90, height: 90)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

private struct MusicDecorationContent: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "music.note")
                .font(.system(size: 26))
                .foregroundColor(Color(red: 0.95, green: 0.25, blue: 0.35))
            Text("Music")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.black.opacity(0.6))
        }
        .frame(width: 80, height: 80)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 6))
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

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Spacer()
                Text(display)
                    .font(.system(size: 56, weight: .light, design: .rounded))
                    .foregroundColor(.primary)
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
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                Spacer()
            }
            .navigationTitle("Calculator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func backgroundColor(for symbol: String) -> Color {
        if symbol == "C" || symbol == "±" || symbol == "%" { return Color(.systemGray4) }
        if ["÷", "×", "−", "+", "="].contains(symbol) { return Color(red: 0.95, green: 0.55, blue: 0.15) }
        return Color(.systemGray5)
    }

    private func foregroundColor(for symbol: String) -> Color {
        if ["÷", "×", "−", "+", "="].contains(symbol) { return .white }
        if symbol == "C" || symbol == "±" || symbol == "%" { return .black }
        return .primary
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
