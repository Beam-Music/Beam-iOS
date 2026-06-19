import Foundation

protocol AudioManagerProtocol {
    func play() async
    func pause() async
    func stop() async
    func playAIMusic(from urlString: String, title: String, artist: String, artworkURL: URL?) async throws
    func isPlaying() async -> Bool
    func tryResume() async -> Bool
    func seek(to seconds: Double) async
    var isAIPlaying: Bool { get }
}
