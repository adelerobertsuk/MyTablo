import Foundation
import SwiftData

@Model
final class Decoration: Identifiable {
    var imageName: String
    var x: Double = 150
    var y: Double = 200
    var rotation: Double = 0
    var scale: Double = 1.0
    var zIndex: Double = 0

    init(imageName: String, x: Double = 150, y: Double = 200, rotation: Double = 0, scale: Double = 1.0, zIndex: Double = 0) {
        self.imageName = imageName
        self.x = x
        self.y = y
        self.rotation = rotation
        self.scale = scale
        self.zIndex = zIndex
    }
}
