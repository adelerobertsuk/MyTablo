import SwiftUI

struct DecorationView: View {
    let decoration: Decoration
    var isSelected: Bool = false
    var isInteractive: Bool = true
    var onSelect: () -> Void = {}
    var onUpdate: (Double, Double, Double, Double) -> Void = { _, _, _, _ in }
    var onDelete: () -> Void = {}

    @State private var dragOffset: CGSize = .zero
    @GestureState private var magnifyBy: CGFloat = 1.0
    @GestureState private var rotateBy: Angle = .zero

    private var cardView: some View {
        ZStack(alignment: .topTrailing) {
            Image(decoration.imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 70, height: 70)
                .shadow(color: .black.opacity(isSelected ? 0.3 : 0.18), radius: isSelected ? 8 : 4, x: 2, y: 3)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: isSelected ? 2 : 0)
                )

            if isInteractive, isSelected {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .background(Circle().fill(Color.black.opacity(0.6)).frame(width: 14, height: 14))
                }
                .offset(x: 6, y: -6)
            }
        }
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
            cardView
                .frame(width: 88, height: 88)
                .contentShape(Rectangle())
                .scaleEffect(decoration.scale * magnifyBy)
                .rotationEffect(.degrees(decoration.rotation + rotateBy.degrees))
                .position(x: decoration.x + dragOffset.width, y: decoration.y + dragOffset.height)
                .gesture(dragMagnifyRotateGesture)
                .onTapGesture {
                    onSelect()
                }
        } else {
            cardView
                .scaleEffect(decoration.scale)
                .rotationEffect(.degrees(decoration.rotation))
                .position(x: decoration.x, y: decoration.y)
        }
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
