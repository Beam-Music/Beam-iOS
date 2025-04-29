import Foundation

protocol AudioManagerProtocol {
    func play() async
    func pause() async
    func stop() async
    func playAppleMusicTrack(title: String?, storeID: String?) async throws
    func playAIMusic(from urlString: String) async throws
    func isPlaying() async -> Bool
    func tryResume() async -> Bool
    func seek(to seconds: Double) async
    var isAIPlaying: Bool { get }
} 