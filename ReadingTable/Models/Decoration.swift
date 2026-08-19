import Foundation
import SwiftData
import SwiftUI

@Model
final class Decoration: Identifiable {
    /// Sticky notes use this sentinel instead of a real asset name.
    static let stickyNoteImageName = "sticky-note"
    /// Photo decorations use this sentinel instead of a real asset name.
    static let photoFrameImageName = "photo-frame"
    /// Calendar decorations use this sentinel instead of a real asset name.
    static let calendarImageName = "calendar-decoration"
    /// Weather decorations use this sentinel instead of a real asset name.
    static let weatherImageName = "weather-decoration"
    /// Clock decorations use this sentinel instead of a real asset name.
    static let clockImageName = "clock-decoration"
    /// Calculator decorations use this sentinel instead of a real asset name.
    static let calculatorImageName = "calculator-decoration"
    /// Music decorations use this sentinel instead of a real asset name.
    static let musicImageName = "music-decoration"
    /// Location decorations use this sentinel instead of a real asset name.
    static let locationImageName = "location-decoration"

    var imageName: String
    var x: Double = 150
    var y: Double = 200
    var rotation: Double = 0
    var scale: Double = 1.0
    var zIndex: Double = 0
    var noteText: String? = nil
    var noteColorName: String? = nil
    var noteInkData: Data? = nil
    var photoImageData: Data? = nil
    var clockStyleName: String? = nil

    init(
        imageName: String,
        x: Double = 150,
        y: Double = 200,
        rotation: Double = 0,
        scale: Double = 1.0,
        zIndex: Double = 0,
        noteText: String? = nil,
        noteColorName: String? = nil,
        noteInkData: Data? = nil,
        photoImageData: Data? = nil,
        clockStyleName: String? = nil
    ) {
        self.imageName = imageName
        self.x = x
        self.y = y
        self.rotation = rotation
        self.scale = scale
        self.zIndex = zIndex
        self.noteText = noteText
        self.noteColorName = noteColorName
        self.noteInkData = noteInkData
        self.photoImageData = photoImageData
        self.clockStyleName = clockStyleName
    }

    var isStickyNote: Bool { imageName == Decoration.stickyNoteImageName }
    var isPhotoFrame: Bool { imageName == Decoration.photoFrameImageName }
    var isCalendar: Bool { imageName == Decoration.calendarImageName }
    var isWeather: Bool { imageName == Decoration.weatherImageName }
    var isClock: Bool { imageName == Decoration.clockImageName }
    var isCalculator: Bool { imageName == Decoration.calculatorImageName }
    var isMusic: Bool { imageName == Decoration.musicImageName }
    var isLocation: Bool { imageName == Decoration.locationImageName }
    var isAnalogClock: Bool { clockStyleName == "analog" }
}

enum StickyNoteColor: String, CaseIterable, Identifiable {
    case yellow, pink, blue, green

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .yellow: return Color(red: 1.0, green: 0.92, blue: 0.55)
        case .pink: return Color(red: 1.0, green: 0.78, blue: 0.85)
        case .blue: return Color(red: 0.72, green: 0.87, blue: 1.0)
        case .green: return Color(red: 0.78, green: 0.93, blue: 0.73)
        }
    }
}
