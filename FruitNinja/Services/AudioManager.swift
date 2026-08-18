import AppKit
import SpriteKit

enum BundleResource {
    static let artDirectories = [nil, "Art", "Resources/Art"]
    static let audioDirectories = [nil, "Audio", "Resources/Audio"]

    static func url(name: String, ext: String, directories: [String?]) -> URL? {
        for subdirectory in directories {
            if let url = Bundle.main.url(forResource: name,
                                         withExtension: ext,
                                         subdirectory: subdirectory) {
                return url
            }
        }
        if let resourceURL = Bundle.main.resourceURL {
            for subdirectory in directories.compactMap({ $0 }) {
                let candidate = resourceURL
                    .appendingPathComponent(subdirectory, isDirectory: true)
                    .appendingPathComponent("\(name).\(ext)")
                if FileManager.default.fileExists(atPath: candidate.path) {
                    return candidate
                }
            }
        }
        return nil
    }
}

enum Art {
    private static var cache: [String: SKTexture] = [:]

    static func texture(named name: String) -> SKTexture? {
        if let cached = cache[name] {
            return cached
        }
        if let url = BundleResource.url(name: name, ext: "png", directories: BundleResource.artDirectories),
           let image = NSImage(contentsOf: url) {
            let texture = SKTexture(image: image)
            texture.filteringMode = .linear
            cache[name] = texture
            return texture
        }
        if let image = NSImage(named: name) {
            let texture = SKTexture(image: image)
            cache[name] = texture
            return texture
        }
        return nil
    }

    static func menuBackground() -> NSImage? {
        if let url = BundleResource.url(name: "menu_background", ext: "png",
                                        directories: BundleResource.artDirectories) {
            return NSImage(contentsOf: url)
        }
        return nil
    }

    static func fallbackTexture(color: NSColor, size: CGFloat = 128) -> SKTexture {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            color.setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 4, dy: 4)).fill()
            NSColor.white.withAlphaComponent(0.25).setFill()
            NSBezierPath(ovalIn: NSRect(x: rect.width * 0.18, y: rect.height * 0.55,
                                        width: rect.width * 0.3, height: rect.height * 0.25)).fill()
            return true
        }
        return SKTexture(image: image)
    }
}

final class AudioManager {
    static let shared = AudioManager()

    var musicVolume: Float = 0.65 {
        didSet {
            musicPlayer?.volume = paused ? 0 : musicVolume
        }
    }
    var sfxVolume: Float = 0.8

    private var musicPlayer: AVAudioPlayer?
    private var currentTrack: String?
    private var paused = false
    private var sfxPools: [String: [NSSound]] = [:]
    private var sfxIndexes: [String: Int] = [:]

    private init() {}

    func playMenuMusic() {
        playMusic(named: "music_menu")
    }

    func playGameMusic() {
        playMusic(named: "music_game")
    }

    func stopMusic() {
        musicPlayer?.stop()
        musicPlayer = nil
        currentTrack = nil
        paused = false
    }

    func setPaused(_ value: Bool) {
        guard paused != value else { return }
        paused = value
        if value {
            musicPlayer?.setVolume(0, fadeDuration: 0.12)
            musicPlayer?.pause()
        } else {
            musicPlayer?.play()
            musicPlayer?.setVolume(musicVolume, fadeDuration: 0.18)
        }
    }

    func play(_ sfx: String) {
        guard sfxVolume > 0.001 else { return }
        var pool = sfxPools[sfx] ?? []
        if pool.isEmpty {
            for _ in 0..<4 {
                if let sound = Self.loadSound(named: sfx) {
                    pool.append(sound)
                }
            }
            sfxPools[sfx] = pool
        }
        guard !pool.isEmpty else { return }
        let index = (sfxIndexes[sfx] ?? 0) % pool.count
        sfxIndexes[sfx] = (index + 1) % pool.count
        let sound = pool[index]
        sound.volume = sfxVolume
        if sound.isPlaying {
            sound.stop()
        }
        sound.play()
    }

    func stopAll() {
        stopMusic()
        for pool in sfxPools.values {
            for sound in pool { sound.stop() }
        }
    }

    private func playMusic(named name: String) {
        guard currentTrack != name else {
            if musicPlayer?.isPlaying == false {
                musicPlayer?.play()
            }
            return
        }
        musicPlayer?.stop()
        guard let url = BundleResource.url(name: name, ext: "caf",
                                           directories: BundleResource.audioDirectories) else {
            NSLog("Fruit Slice: missing music %@", name)
            return
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.volume = musicVolume
            player.prepareToPlay()
            player.play()
            musicPlayer = player
            currentTrack = name
            paused = false
        } catch {
            NSLog("Fruit Slice: could not play music %@: %@", name, error.localizedDescription)
        }
    }

    private static func loadSound(named name: String) -> NSSound? {
        guard let url = BundleResource.url(name: name, ext: "caf",
                                           directories: BundleResource.audioDirectories) else {
            return nil
        }
        return NSSound(contentsOf: url, byReference: false)
    }
}
