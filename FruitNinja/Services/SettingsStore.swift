import Foundation

final class SettingsStore {
    static let shared = SettingsStore()

    private enum Key {
        static let playerName = "playerName"
        static let difficulty = "difficulty"
        static let musicVolume = "musicVolume"
        static let sfxVolume = "sfxVolume"
        static let useMouse = "useMouseMode"
        static let firstLaunch = "hasLaunched"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.playerName: "Player",
            Key.difficulty: Difficulty.normal.rawValue,
            Key.musicVolume: 0.65,
            Key.sfxVolume: 0.8,
            Key.useMouse: false,
        ])
    }

    var playerName: String {
        get {
            let value = defaults.string(forKey: Key.playerName)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return (value?.isEmpty == false) ? String(value!.prefix(18)) : "Player"
        }
        set {
            let clean = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            defaults.set(clean.isEmpty ? "Player" : String(clean.prefix(18)),
                         forKey: Key.playerName)
        }
    }

    var difficulty: Difficulty {
        get { Difficulty(rawValue: defaults.string(forKey: Key.difficulty) ?? "") ?? .normal }
        set { defaults.set(newValue.rawValue, forKey: Key.difficulty) }
    }

    var musicVolume: Float {
        get { min(1, max(0, defaults.float(forKey: Key.musicVolume))) }
        set { defaults.set(min(1, max(0, newValue)), forKey: Key.musicVolume) }
    }

    var sfxVolume: Float {
        get { min(1, max(0, defaults.float(forKey: Key.sfxVolume))) }
        set { defaults.set(min(1, max(0, newValue)), forKey: Key.sfxVolume) }
    }

    var useMouseMode: Bool {
        get { defaults.bool(forKey: Key.useMouse) }
        set { defaults.set(newValue, forKey: Key.useMouse) }
    }

    var isFirstLaunch: Bool {
        get { !defaults.bool(forKey: Key.firstLaunch) }
        set { defaults.set(!newValue, forKey: Key.firstLaunch) }
    }
}
