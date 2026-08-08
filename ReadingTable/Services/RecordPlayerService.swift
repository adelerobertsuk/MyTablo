import AVFoundation
import Combine
import Foundation
import SwiftUI

struct RecordTrack: Identifiable {
    let id: Int
    let title: String
    let artist: String
    let fileName: String
    let labelColor: Color
}

@MainActor
final class RecordPlayerService: NSObject, ObservableObject {
    static let shared = RecordPlayerService()

    @Published private(set) var currentIndex: Int = 0
    @Published private(set) var isPlaying: Bool = false

    /// Bundled royalty-free lo-fi/study tracks (Pixabay Music, 2026-08-08) — each gets its own
    /// "album" label color so switching tracks visibly changes the record, per Adele/Kate's request.
    let tracks: [RecordTrack] = [
        RecordTrack(id: 0, title: "Calm Peaceful Chill Hop", artist: "FASSounds", fileName: "record-track-1",
                    labelColor: Color(red: 0.83, green: 0.62, blue: 0.25)),
        RecordTrack(id: 1, title: "Study Session", artist: "alex-morgan", fileName: "record-track-2",
                    labelColor: Color(red: 0.78, green: 0.42, blue: 0.35)),
        RecordTrack(id: 2, title: "Lofi Study", artist: "The_Mountain", fileName: "record-track-3",
                    labelColor: Color(red: 0.29, green: 0.42, blue: 0.31)),
        RecordTrack(id: 3, title: "Rainy Night", artist: "alex-morgan", fileName: "record-track-4",
                    labelColor: Color(red: 0.24, green: 0.28, blue: 0.42)),
        RecordTrack(id: 4, title: "Study Lofi", artist: "mirostar", fileName: "record-track-5",
                    labelColor: Color(red: 0.5, green: 0.28, blue: 0.42))
    ]

    var currentTrack: RecordTrack { tracks[currentIndex] }

    private var player: AVAudioPlayer?
    private var loadedIndex: Int?

    private override init() {
        super.init()
    }

    func togglePlayPause() {
        isPlaying ? pause() : play()
    }

    func play() {
        if loadedIndex != currentIndex {
            loadTrack(at: currentIndex)
        }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        player?.play()
        isPlaying = true
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }

    func skipToNext() {
        currentIndex = (currentIndex + 1) % tracks.count
        loadTrack(at: currentIndex)
        if isPlaying { player?.play() }
    }

    func skipToPrevious() {
        currentIndex = (currentIndex - 1 + tracks.count) % tracks.count
        loadTrack(at: currentIndex)
        if isPlaying { player?.play() }
    }

    private func loadTrack(at index: Int) {
        guard let url = Bundle.main.url(forResource: tracks[index].fileName, withExtension: "mp3") else { return }
        player = try? AVAudioPlayer(contentsOf: url)
        player?.numberOfLoops = -1
        player?.volume = 0.9
        player?.prepareToPlay()
        loadedIndex = index
    }
}
