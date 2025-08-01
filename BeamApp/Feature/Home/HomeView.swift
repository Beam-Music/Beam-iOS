//
//  HomeView.swift
//  BeamPrac
//
//  Created by freed on 9/10/24.
//

import SwiftUI
import ComposableArchitecture
import MusicKit

// MARK: - AI Convert Helper Functions
func uploadFileToAIConvert(fileURL: URL, completion: @escaping (Result<URL, Error>) -> Void) {
    let url = URL(string: "\(Endpoints.baseURL)/ai-convert/remix")! // AI 변환 엔드포인트
    var request = URLRequest(url: url)
    request.httpMethod = "POST"

    let boundary = "Boundary-\(UUID().uuidString)"
    request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

    var data = Data()
    let filename = fileURL.lastPathComponent
    let mimetype = "audio/mpeg" // mp3 등 실제 파일 타입에 맞게

    guard let fileData = try? Data(contentsOf: fileURL) else {
        completion(.failure(NSError(domain: "FileError", code: 0, userInfo: [NSLocalizedDescriptionKey: "파일을 읽을 수 없습니다."])))
        return
    }

    data.append("--\(boundary)\r\n".data(using: .utf8)!)
    data.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
    data.append("Content-Type: \(mimetype)\r\n\r\n".data(using: .utf8)!)
    data.append(fileData)
    data.append("\r\n".data(using: .utf8)!)
    data.append("--\(boundary)--\r\n".data(using: .utf8)!)

    let task = URLSession.shared.uploadTask(with: request, from: data) { responseData, response, error in
        if let error = error {
            completion(.failure(error))
            return
        }
        guard let responseData = responseData else {
            completion(.failure(NSError(domain: "NoData", code: 0, userInfo: nil)))
            return
        }
        // 임시 파일로 저장
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("ai_version.mp3")
        do {
            try responseData.write(to: tempURL)
            completion(.success(tempURL))
        } catch {
            completion(.failure(error))
        }
    }
    task.resume()
}

struct MusicSearchResult: Identifiable, Hashable, Equatable {
    let id: String
    let title: String
    let artist: String
    let artworkURL: URL?
    let isExplicit: Bool
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: MusicSearchResult, rhs: MusicSearchResult) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Music Search Service
class MusicSearchService {
    func searchMusic(query: String) async throws -> [MusicSearchResult] {
        let status = await MusicAuthorization.request()
        guard status == .authorized else {
            throw NSError(domain: "MusicAuthorizationFailed", code: 401)
        }
        var searchRequest = MusicCatalogSearchRequest(term: query, types: [MusicKit.Song.self])
        searchRequest.limit = 25
        let response = try await searchRequest.response()
        let songResults: [MusicSearchResult] = response.songs.compactMap { song in
            MusicSearchResult(
                id: song.id.rawValue,
                title: song.title,
                artist: song.artistName,
                artworkURL: song.artwork?.url(width: 100, height: 100),
                isExplicit: song.contentRating == .explicit
            )
        }
        return songResults
    }
}

// MARK: - Music Search Result View
struct MusicSearchResultView: View {
    let result: MusicSearchResult
    let onPlay: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let artworkURL = result.artworkURL {
                    AsyncImage(url: artworkURL) { image in
                        image.resizable()
                    } placeholder: {
                        Color.gray.opacity(0.3)
                    }
                } else {
                    Image(systemName: "music.note")
                        .foregroundColor(.gray)
                        .background(Color.gray.opacity(0.2))
                }
            }
            .frame(width: 50, height: 50)
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(result.title)
                        .font(.headline)
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .lineLimit(1)
                    
                    if result.isExplicit {
                        Text("E")
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.5))
                            .cornerRadius(3)
                    }
                }
                
                Text(result.artist)
                    .font(.subheadline)
                    .foregroundColor(colorScheme == .dark ? .gray : .gray)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button(action: onPlay) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.purple)
            }
        }
        .padding()
        .background(colorScheme == .dark ? Color.black.opacity(0.2) : Color.white)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(colorScheme == .dark ? Color.purple.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

struct HomeView: View {
    @Binding var isLoggedIn: Bool
    @Binding var isMiniPlayerVisible: Bool
    let store: StoreOf<AppReducer>
    let libraryStore: StoreOf<LibraryReducer>
    @Environment(\.colorScheme) var colorScheme
    @State private var selectedTab: Int = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var hitSongs: [MusicSearchResult] = []
    @State private var remixArtistPairs: [RemixArtistPair] = []
    @State private var songToAddToPlaylist: MusicSearchResult? = nil
    @State private var isPlaylistSelectSheetPresented: Bool = false
    @State private var isLoadingHitSongs: Bool = true
    @State private var isLoadingRemixPairs: Bool = true
    @State private var isRemixingDemo = false
    
    private var homeStore: StoreOf<HomeReducer> {
        store.scope(state: \.tabBarState.homeState, action: { AppReducer.Action.tabBar(.home($0)) })
    }
    private var viewStore: ViewStore<HomeReducer.State, HomeReducer.Action> {
        ViewStore(homeStore, observe: { $0 })
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.purple.opacity(0.7), Color.pink.opacity(0.5)]),
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            // Animated star field background
            StarFieldView(starCount: 40, scrollOffset: scrollOffset)
            
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    TextField("노래/가수 검색하기", text: viewStore.binding(
                        get: \.searchText,
                        send: HomeReducer.Action.searchTextChanged
                    ))
                    .padding(.vertical, 10)
                    .padding(.horizontal, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.7), lineWidth: 1.2)
                    )
                    .foregroundColor(.white)
                    .font(.system(size: 17, weight: .medium))
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    
                    if !viewStore.searchText.isEmpty {
                        Button(action: {
                            viewStore.send(.clearSearchResults)
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 32)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("히트 음악")
                                .font(.title2).bold()
                                .foregroundColor(.white)
                            Spacer()
                            Button("전체보기") {
                                // 전체보기 액션 (필요시)
                            }
                            .foregroundColor(.white.opacity(0.7))
                            .font(.subheadline)
                        }
                        .padding(.horizontal)
                        Spacer().frame(height: 10)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 28) {
                                if isLoadingHitSongs {
                                    // 로딩 중일 때 플레이스홀더
                                    ForEach(0..<5, id: \.self) { _ in
                                        HitSongCardPlaceholder()
                                    }
                                } else {
                                    ForEach(hitSongs.indices, id: \.self) { idx in
                                        let song = hitSongs[idx]
                                        HitSongCardView(
                                            song: song,
                                            onPlay: {
                                                viewStore.send(.playMusic(song))
                                                isMiniPlayerVisible = true
                                            },
                                            onAdd: {
                                                songToAddToPlaylist = song
                                                isPlaylistSelectSheetPresented = true
                                            }
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.top, 10)
                        .frame(height: 180) // 고정된 높이 설정
                        // 리믹스할 가수조합 추천 섹션
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("리믹스할 가수조합 추천")
                                    .font(.title2).bold()
                                    .foregroundColor(.white)
                                Spacer()
                                Button("전체보기") {
                                    // 전체보기 액션 (필요시)
                                }
                                .foregroundColor(.white.opacity(0.7))
                                .font(.subheadline)
                            }
                            .padding(.horizontal)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 32) {
                                    if isLoadingRemixPairs {
                                        // 로딩 중일 때 플레이스홀더
                                        ForEach(0..<3, id: \.self) { _ in
                                            RemixArtistPairPlaceholder()
                                        }
                                    } else {
                                        ForEach(remixArtistPairs) { pair in
                                            RemixArtistPairView(pair: pair, onRemix: { fileName in
                                                if let fileURL = Bundle.main.url(forResource: fileName, withExtension: nil) {
                                                    isRemixingDemo = true
                                                    uploadFileToAIConvert(fileURL: fileURL) { result in
                                                        DispatchQueue.main.async {
                                                            isRemixingDemo = false
                                                            switch result {
                                                            case .success(let url):
                                                                Task {
                                                                    do {
                                                                        try await AudioManager.shared.playAIMusic(from: url.absoluteString, title: pair.artist2, artist: pair.artist1)
                                                                    } catch {
                                                                        print("AI 변환 곡 재생 실패: \(error)")
                                                                    }
                                                                }
                                                            case .failure(let error):
                                                                print("AI 변환 실패: \(error)")
                                                            }
                                                        }
                                                    }
                                                }
                                            })
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                            .padding(.top, 10)
                            .frame(height: 150) // 고정된 높이 설정
                        }
                    }
                    .padding(.top, 20)
                    
                    GeometryReader { geo in
                        Color.clear
                            .preference(key: ScrollOffsetPreferenceKey.self, value: geo.frame(in: .global).minY)
                    }
                    .frame(height: 0)
                    
                    if viewStore.isSearching {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                            .frame(maxWidth: .infinity, minHeight: 100)
                            .padding(.top, 20)
                    }
                    
                    if let error = viewStore.error {
                        Text("검색 오류: \(error)")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.red.opacity(0.5))
                            .cornerRadius(8)
                            .padding()
                    }
                    
                    if !viewStore.searchResults.isEmpty {
                        VStack(spacing: 12) {
                            Text("검색 결과")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                                .padding(.top, 8)
                            
                            ForEach(viewStore.searchResults) { result in
                                MusicSearchResultView(result: result) {
                                    viewStore.send(.playMusic(result))
                                    isMiniPlayerVisible = true
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.vertical)
                    }
                    else if viewStore.searchText.isEmpty {
                        if !viewStore.playlists.isEmpty {
                            PlaylistListView(
                                playlists: viewStore.playlists,
                                onPlaylistSelected: { playlist in
                                    viewStore.send(.playlistSelected(playlist))
                                }
                            )
                        } else {
                            // VStack(spacing: 16) {
                            //     Text("재생 목록이 없습니다")
                            //         .font(.headline)
                            //         .foregroundColor(.white)
                            //         .padding(.top, 40)
                                
                            //     Text("첫 번째 재생 목록을 만들어보세요!")
                            //         .font(.subheadline)
                            //         .foregroundColor(.white.opacity(0.8))
                            // }
                            // .frame(maxWidth: .infinity)
                            // .padding(.top, 60)
                        }
                    }
                }
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    scrollOffset = value
                }
            }

            MusicSearchView(isMiniPlayerVisible: $isMiniPlayerVisible)
        }
        .navigationBarItems(trailing: HomeNavigationBarView(store: store, isLoggedIn: $isLoggedIn))
        .navigationBarTitle("", displayMode: .inline)
        .onAppear {
            Task {
                await fetchAppleMusicHitSongs()
                await fetchRemixArtistPairs()
            }
        }
    }
    
    // 실시간 차트 곡 불러오는 함수
    private func fetchAppleMusicHitSongs() async {
        do {
            var request = MusicCatalogChartsRequest(types: [MusicKit.Song.self])
            request.limit = 10
            let response = try await request.response()
            let topSongs = response.songCharts.first?.items ?? []
            let results = topSongs.map { song in
                MusicSearchResult(
                    id: song.id.rawValue,
                    title: song.title,
                    artist: song.artistName,
                    artworkURL: song.artwork?.url(width: 100, height: 100),
                    isExplicit: song.contentRating == .explicit
                )
            }
            await MainActor.run {
                self.hitSongs = results
                self.isLoadingHitSongs = false
            }
        } catch {
            await MainActor.run {
                self.isLoadingHitSongs = false
            }
        }
    }

    // MARK: - 리믹스 가수조합 데이터 및 뷰
    struct RemixArtistPair: Identifiable {
        let id = UUID()
        let artist1: String
        let artist2: String
        var artworkURL1: URL?
        var artworkURL2: URL?
        var fileName: String? // 내장 mp3 파일명 (있으면 AI Remix 가능)
    }

    struct RemixArtistPairView: View {
        let pair: RemixArtistPair
        var onRemix: ((String) -> Void)? // fileName 전달

        var body: some View {
            VStack(spacing: 10) {
                ZStack {
                    if let url1 = pair.artworkURL1 {
                        AsyncImage(url: url1) { image in
                            image.resizable()
                        } placeholder: {
                            Color.gray.opacity(0.3)
                        }
                        .clipShape(HalfCircle(left: true))
                    }
                    if let url2 = pair.artworkURL2 {
                        AsyncImage(url: url2) { image in
                            image.resizable()
                        } placeholder: {
                            Color.gray.opacity(0.3)
                        }
                        .clipShape(HalfCircle(left: false))
                    }
                }
                .frame(width: 100, height: 100)
                Button(action: {
                    if let fileName = pair.fileName {
                        onRemix?(fileName)
                    }
                }) {
                    HStack(spacing: 4) {
                        Text("청음하기")
                        Image(systemName: "play.circle.fill")
                    }
                    .foregroundColor(.white)
                    .font(.headline)
                }
                .disabled(pair.fileName == nil)
                .opacity(pair.fileName == nil ? 0.5 : 1.0)
            }
        }
    }

    struct HalfCircle: Shape {
        let left: Bool
        func path(in rect: CGRect) -> Path {
            var path = Path()
            if left {
                path.addArc(center: CGPoint(x: rect.midX, y: rect.midY), radius: rect.width/2, startAngle: .degrees(90), endAngle: .degrees(270), clockwise: false)
                path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
                path.closeSubpath()
            } else {
                path.addArc(center: CGPoint(x: rect.midX, y: rect.midY), radius: rect.width/2, startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: false)
                path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
                path.closeSubpath()
            }
            return path
        }
    }

    // 가수조합을 MusicKit으로 검색해서 artworkURL을 채움 (데모용 하드코딩)
    private func fetchRemixArtistPairs() async {
        let pairs: [(String, String, String?)] = [
            ("Dua Lipa", "H.E.R", nil),
            ("Rihanna", "BlackPink", nil),
            ("WOODZ", "NewJeans", nil),
            // 내장곡 추가
            ("Coldplay", "Fix You", "fixyou.mp3"),
            ("Coldplay", "Feels Like Falling In Love", "feelslikefallinginlove.mp3")
        ]
        var result: [RemixArtistPair] = []
        for (a1, a2, fileName) in pairs {
            let url1 = await fetchArtistArtworkURL(artist: a1)
            let url2 = await fetchArtistArtworkURL(artist: a2)
            result.append(RemixArtistPair(artist1: a1, artist2: a2, artworkURL1: url1, artworkURL2: url2, fileName: fileName))
        }
        await MainActor.run { 
            self.remixArtistPairs = result 
            self.isLoadingRemixPairs = false
        }
    }

    private func fetchArtistArtworkURL(artist: String) async -> URL? {
        do {
            let request = MusicCatalogSearchRequest(term: artist, types: [MusicKit.Artist.self])
            let response = try await request.response()
            if let artist = response.artists.first, let url = artist.artwork?.url(width: 200, height: 200) {
                return url
            }
        } catch {}
        return nil
    }
}

// MARK: - Setup for Previews
extension PlaylistSummaryDTO {
    static let mockPlaylists: [PlaylistSummaryDTO] = [
        PlaylistSummaryDTO(id: UUID(), name: "좋아하는 노래"),
        PlaylistSummaryDTO(id: UUID(), name: "드라이브 음악", user: PlaylistSummaryDTO.User(id: UUID(), username: "사용자")),
        PlaylistSummaryDTO(id: UUID(), name: "Work Out")
    ]
}

// struct HomeView_Previews: PreviewProvider {
//     static var previews: some View {
//         NavigationView {
//             HomeView(
//                 isLoggedIn: .constant(true),
//                 isMiniPlayerVisible: .constant(false),
//                 store: Store(
//                     initialState: HomeReducer.State(
//                         playlists: PlaylistSummaryDTO.mockPlaylists
//                     ),
//                     reducer: HomeReducer()
//                 )
//             )
//         }
//     }
// }

struct Star: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var opacity: Double
}

struct StarFieldView: View {
    let starCount: Int
    let scrollOffset: CGFloat
    @State private var stars: [Star] = []

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(stars) { star in
                    Circle()
                        .fill(Color.white.opacity(star.opacity))
                        .frame(width: star.size, height: star.size)
                        .position(
                            x: star.x * geo.size.width,
                            y: (star.y * geo.size.height + scrollOffset).truncatingRemainder(dividingBy: geo.size.height)
                        )
                }
            }
            .onAppear {
                if stars.isEmpty {
                    stars = (0..<starCount).map { _ in
                        Star(
                            x: .random(in: 0...1),
                            y: .random(in: 0...1),
                            size: .random(in: 2...7),
                            opacity: .random(in: 0.3...0.9)
                        )
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct PlaylistListView: View {
    let playlists: [PlaylistSummaryDTO]
    let onPlaylistSelected: (PlaylistSummaryDTO) -> Void
    @Environment(\.colorScheme) var colorScheme
    var body: some View {
        List(playlists, id: \.id) { playlist in
            Button(action: { onPlaylistSelected(playlist) }) {
                Text(playlist.name)
                    .foregroundColor(colorScheme == .dark ? .white : .black)
            }
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
    }
}

struct MusicSearchView: View {
    @Binding var isMiniPlayerVisible: Bool
    var body: some View {
        EmptyView()
    }
}

struct HomeNavigationBarView: View {
    let store: StoreOf<AppReducer>
    @Binding var isLoggedIn: Bool
    var body: some View {
        NavigationLink(destination: SettingsView(store: store, isLoggedIn: $isLoggedIn)) {
            Image(systemName: "gearshape")
                .font(.system(size: 20))
                .foregroundColor(Color.purple)
        }
    }
}

struct HitSongCardView: View {
    let song: MusicSearchResult
    let onPlay: () -> Void
    let onAdd: () -> Void
    @State private var fetchedArtworkURL: URL? = nil
    @State private var isFetching: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                if let url = song.artworkURL ?? fetchedArtworkURL {
                    AsyncImage(url: url) { image in
                        image.resizable()
                    } placeholder: {
                        Color.gray.opacity(0.3)
                    }
                    .frame(width: 110, height: 110)
                    .cornerRadius(16)
                } else if isFetching {
                    ProgressView()
                        .frame(width: 110, height: 110)
                } else {
                    Color.gray.opacity(0.2)
                        .frame(width: 110, height: 110)
                        .cornerRadius(16)
                }
                Button(action: onPlay) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                        .shadow(radius: 2)
                }
                .padding(8)
            }
            Text(song.title)
                .font(.headline)
                .foregroundColor(.white)
                .lineLimit(1)
            Text(song.artist)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(1)
        }
        .frame(width: 130)
        .onAppear {
            if song.artworkURL == nil && !isFetching {
                isFetching = true
                Task {
                    let service = MusicSearchService()
                    do {
                        let results = try await service.searchMusic(query: "\(song.title) \(song.artist)")
                        if let first = results.first, let url = first.artworkURL {
                            fetchedArtworkURL = url
                        }
                    } catch {}
                    isFetching = false
                }
            }
        }
    }
}

// MARK: - 플레이스홀더 뷰들
struct HitSongCardPlaceholder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 110, height: 110)
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.6)))
                    .scaleEffect(0.8)
            }
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.2))
                .frame(width: 80, height: 16)
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.15))
                .frame(width: 60, height: 14)
        }
        .frame(width: 130)
    }
}

struct RemixArtistPairPlaceholder: View {
    var body: some View {
        VStack(spacing: 10) {
            Circle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 100, height: 100)
                .overlay(
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.6)))
                        .scaleEffect(0.8)
                )
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.2))
                .frame(width: 70, height: 16)
        }
    }
}
