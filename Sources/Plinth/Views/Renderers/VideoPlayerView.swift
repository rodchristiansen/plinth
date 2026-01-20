import AVKit
import SwiftUI

// MARK: - Native Video Player

struct NativeVideoPlayer: NSViewRepresentable {
    let url: URL
    let loop: Bool
    
    func makeNSView(context: Context) -> AVPlayerView {
        let playerView = AVPlayerView()
        playerView.controlsStyle = .none
        playerView.showsFullScreenToggleButton = false
        
        let playerItem = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: playerItem)
        player.isMuted = false
        
        playerView.player = player
        
        if loop {
            context.coordinator.setupLooping(player: player)
        }
        
        player.play()
        
        return playerView
    }
    
    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        // URL changes are not supported during playback
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject {
        private var loopObserver: NSObjectProtocol?
        
        func setupLooping(player: AVPlayer) {
            loopObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem,
                queue: .main
            ) { [weak player] _ in
                player?.seek(to: .zero)
                player?.play()
            }
        }
        
        deinit {
            if let observer = loopObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
}

// MARK: - Video Player View

struct VideoPlayerView: View {
    let url: URL
    let loop: Bool
    
    var body: some View {
        NativeVideoPlayer(url: url, loop: loop)
            .ignoresSafeArea()
    }
}

#Preview {
    VideoPlayerView(
        url: URL(fileURLWithPath: "/System/Library/Compositions/Eiffel Tower.mov"),
        loop: true
    )
}
