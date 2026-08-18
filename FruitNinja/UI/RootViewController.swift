import AppKit
import AVFoundation
import SpriteKit

final class RootViewController: NSViewController {
    private let settings = SettingsStore.shared
    private let leaderboard = LeaderboardStore()
    private let audio = AudioManager.shared
    private let tracker = FNHandTracker()

    private let backgroundImageView = NSImageView()
    private let mouseBackdrop = NSView()
    private let cameraContainer = NSView()
    private let skView = TrackingSKView()
    private var overlayView: NSView?

    private var gameScene: GameScene?
    private var latestHandSample: FNHandSample?
    private var mousePoint: CGPoint?
    private var mouseInside = false
    private var eventMonitor: Any?
    private var resignObserver: NSObjectProtocol?
    private var isStartingGame = false
    private var gameOverHandled = false

    private var handFPSWindowStart = CACurrentMediaTime()
    private var handSampleCount = 0
    private var handFPS: Double = 0

#if DEBUG
    private let debugAutoSlice =
        ProcessInfo.processInfo.environment["FRUITSLICE_AUTOSLICE"] == "1"
    private let debugCaptureSlices =
        ProcessInfo.processInfo.environment["FRUITSLICE_CAPTURE_SLICES"] == "1"
    private var debugSliceCaptureCount = 0
    private var debugSweepSide: CGFloat = 1
    private var debugSweepTarget: CGPoint?
#endif

    override func loadView() {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 1280, height: 800))
        root.wantsLayer = true
        root.layer?.backgroundColor = Theme.ink.cgColor
        view = root
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureBackground()
        configureCamera()
        configureGameView()
        tracker.delegate = self
        audio.musicVolume = settings.musicVolume
        audio.sfxVolume = settings.sfxVolume
        installEventMonitor()
        installObservers()
        showMenu()
#if DEBUG
        setupDebugHarnessIfNeeded()
#endif
    }

#if DEBUG
    private func setupDebugHarnessIfNeeded() {
        guard DebugCapture.enabled else { return }
        NSApp.activate(ignoringOtherApps: true)
        view.window?.makeKeyAndOrderFront(nil)
        DispatchQueue.main.async { [weak self] in
            guard let window = self?.view.window else { return }
            NSApp.activate(ignoringOtherApps: true)
            window.collectionBehavior.insert(.moveToActiveSpace)
            window.orderFrontRegardless()
            window.makeKey()
        }

        let environment = ProcessInfo.processInfo.environment
        let screen = environment["FRUITSLICE_SCREEN"] ?? "menu"

        DebugCapture.schedule(delay: 0.8) {
            DebugCapture.captureInterface(name: "01-menu")
        }

        if screen == "settings" {
            DebugCapture.schedule(delay: 1.4) { [weak self] in self?.showSettings() }
            DebugCapture.schedule(delay: 2.2) {
                DebugCapture.captureInterface(name: "02-settings")
            }
            return
        }
        if screen == "leaderboard" {
            DebugCapture.schedule(delay: 1.4) { [weak self] in self?.showLeaderboard() }
            DebugCapture.schedule(delay: 2.2) {
                DebugCapture.captureInterface(name: "02-leaderboard")
            }
            return
        }

        guard environment["FRUITSLICE_AUTOPLAY"] == "mouse" else { return }
        settings.useMouseMode = true
        DebugCapture.schedule(delay: 1.5) { [weak self] in
            self?.startGame(mouseMode: true)
        }
        for (delay, name) in [(2.2, "02-waiting"), (4.2, "03-playing"),
                              (7.0, "04-playing"), (12.0, "05-late"),
                              (17.0, "06-gameover")] {
            DebugCapture.schedule(delay: delay) { [weak self] in
                DebugCapture.captureWindow(name: name)
                if let scene = self?.gameScene {
                    DebugCapture.captureScene(scene, name: name + "-scene")
                }
                if name == "06-gameover" {
                    DebugCapture.captureInterface(name: name + "-interface")
                }
            }
        }

        if environment["FRUITSLICE_AUTOSLICE"] == "1" {
            for index in 0..<16 {
                let delay = 4.6 + Double(index) * 0.4
                DebugCapture.schedule(delay: delay) { [weak self] in
                    guard let scene = self?.gameScene else { return }
                    DebugCapture.captureScene(scene,
                                              name: String(format: "slice-%02d", index))
                }
            }
        }

        if environment["FRUITSLICE_FORCE_GAMEOVER"] == "1" {
            DebugCapture.schedule(delay: 10.0) { [weak self] in
                self?.gameScene?.debugEndGame()
            }
            DebugCapture.schedule(delay: 11.8) { [weak self] in
                DebugCapture.captureWindow(name: "10-gameover")
                if let scene = self?.gameScene {
                    DebugCapture.captureScene(scene, name: "10-gameover-scene")
                }
                DebugCapture.captureInterface(name: "10-gameover-interface")
            }
        }
    }
#endif

    override func viewDidLayout() {
        super.viewDidLayout()
        backgroundImageView.frame = view.bounds
        mouseBackdrop.frame = view.bounds
        cameraContainer.frame = view.bounds
        skView.frame = view.bounds
        overlayView?.frame = view.bounds

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        tracker.previewLayer.frame = cameraContainer.bounds
        CATransaction.commit()

        if let gameScene, gameScene.size != skView.bounds.size {
            gameScene.size = skView.bounds.size
        }
    }

    deinit {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
        if let resignObserver {
            NotificationCenter.default.removeObserver(resignObserver)
        }
        tracker.stop()
        audio.stopAll()
    }

    // MARK: Setup

    private func configureBackground() {
        backgroundImageView.image = Art.menuBackground()
        backgroundImageView.imageScaling = .scaleAxesIndependently
        backgroundImageView.imageAlignment = .alignCenter
        backgroundImageView.autoresizingMask = [.width, .height]
        backgroundImageView.frame = view.bounds
        view.addSubview(backgroundImageView)

        mouseBackdrop.wantsLayer = true
        mouseBackdrop.layer?.backgroundColor = NSColor(calibratedRed: 0.01, green: 0.03,
                                                        blue: 0.05, alpha: 0.72).cgColor
        mouseBackdrop.autoresizingMask = [.width, .height]
        mouseBackdrop.frame = view.bounds
        mouseBackdrop.isHidden = true
        view.addSubview(mouseBackdrop)
    }

    private func configureCamera() {
        cameraContainer.wantsLayer = true
        cameraContainer.layer?.backgroundColor = NSColor.black.cgColor
        cameraContainer.layer?.masksToBounds = true
        cameraContainer.autoresizingMask = [.width, .height]
        cameraContainer.frame = view.bounds
        cameraContainer.isHidden = true
        view.addSubview(cameraContainer)

        tracker.previewLayer.frame = cameraContainer.bounds
        tracker.previewLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        cameraContainer.layer?.addSublayer(tracker.previewLayer)
    }

    private func configureGameView() {
        skView.allowsTransparency = true
        skView.wantsLayer = true
        skView.layer?.backgroundColor = NSColor.clear.cgColor
        skView.ignoresSiblingOrder = true
        skView.preferredFramesPerSecond = 60
        skView.autoresizingMask = [.width, .height]
        skView.frame = view.bounds
        skView.isHidden = true
        skView.onMousePoint = { [weak self] point in
            guard let self else { return }
            self.mousePoint = point
            self.mouseInside = point != nil
        }
        view.addSubview(skView)
    }

    private func installEventMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self else { return event }
            guard self.overlayView == nil, let scene = self.gameScene, !scene.hasEnded else {
                return event
            }
            if event.keyCode == 53 {
                if scene.isUserPaused {
                    scene.resumeGame()
                    self.audio.setPaused(false)
                } else {
                    scene.pauseGame()
                    self.audio.setPaused(scene.isUserPaused)
                }
                return nil
            }
            if let characters = event.charactersIgnoringModifiers?.lowercased() {
                if characters == "m" && scene.isUserPaused {
                    self.showMenu()
                    return nil
                }
                if characters == "d" {
                    scene.toggleDebug()
                    return nil
                }
            }
            return event
        }
    }

    private func installObservers() {
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.autoPauseIfNeeded()
        }
    }

    private func autoPauseIfNeeded() {
#if DEBUG
        // Capture runs launch in the background and can lose key-window
        // status without user intent; do not pause the game being recorded.
        if DebugCapture.enabled { return }
#endif
        guard overlayView == nil, let scene = gameScene, !scene.hasEnded,
              !scene.isUserPaused else { return }
        scene.pauseGame()
        audio.setPaused(scene.isUserPaused)
    }

    // MARK: Screens

    private func presentOverlay(_ screen: NSView) {
        overlayView?.removeFromSuperview()
        screen.frame = view.bounds
        screen.autoresizingMask = [.width, .height]
        view.addSubview(screen)
        overlayView = screen
    }

    private func dismissOverlay() {
        overlayView?.removeFromSuperview()
        overlayView = nil
    }

    private func showMenu() {
        gameOverHandled = false
        teardownGame()
        dismissOverlay()
        cameraContainer.isHidden = true
        mouseBackdrop.isHidden = true
        skView.isHidden = true
        backgroundImageView.isHidden = false

        let menu = MenuView(difficulty: settings.difficulty)
        menu.onPlay = { [weak self] in self?.requestPlay() }
        menu.onLeaderboard = { [weak self] in self?.showLeaderboard() }
        menu.onSettings = { [weak self] in self?.showSettings() }
        menu.onDifficultyChanged = { [weak self] difficulty in
            self?.settings.difficulty = difficulty
        }
        presentOverlay(menu)
        audio.stopMusic()
        audio.playMenuMusic()
        view.window?.makeFirstResponder(nil)
    }

    private func showLeaderboard() {
        let screen = LeaderboardView(store: leaderboard)
        screen.onBack = { [weak self] in self?.showMenu() }
        presentOverlay(screen)
        audio.play("sfx_click")
    }

    private func showSettings() {
        let screen = SettingsView(settings: settings, leaderboard: leaderboard)
        screen.onBack = { [weak self] in self?.showMenu() }
        screen.onAudioSettingsChanged = { [weak self] in
            guard let self else { return }
            self.audio.musicVolume = self.settings.musicVolume
            self.audio.sfxVolume = self.settings.sfxVolume
        }
        screen.onMouseModeChanged = { _ in
            self.audio.play("sfx_click")
        }
        presentOverlay(screen)
        audio.play("sfx_click")
    }

    private func teardownGame() {
        tracker.stop()
        latestHandSample = nil
        mousePoint = nil
        mouseInside = false
        skView.isPaused = true
        skView.presentScene(nil)
        gameScene = nil
    }

    // MARK: Game launch

    private func requestPlay() {
        guard !isStartingGame else { return }
        audio.play("sfx_click")
        if settings.useMouseMode {
            startGame(mouseMode: true)
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            startGame(mouseMode: false)
        case .notDetermined:
            isStartingGame = true
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.isStartingGame = false
                    if granted {
                        self.startGame(mouseMode: false)
                    } else {
                        self.presentCameraDeniedAlert()
                    }
                }
            }
        case .denied, .restricted:
            presentCameraDeniedAlert()
        @unknown default:
            presentCameraDeniedAlert()
        }
    }

    private func startGame(mouseMode: Bool) {
        guard !isStartingGame else { return }
        isStartingGame = true
        dismissOverlay()
        teardownGame()
        gameOverHandled = false
        latestHandSample = nil
        mousePoint = nil
        mouseInside = false
        view.layoutSubtreeIfNeeded()

        cameraContainer.isHidden = mouseMode
        mouseBackdrop.isHidden = !mouseMode
        backgroundImageView.isHidden = false
        skView.isHidden = false
        skView.isPaused = false

        let scene = GameScene(size: skView.bounds.size,
                              difficulty: settings.difficulty,
                              mouseMode: mouseMode)
        wire(scene)
        gameScene = scene
        skView.presentScene(scene)
        view.window?.makeFirstResponder(skView)

        audio.stopMusic()
        audio.setPaused(false)
        audio.playGameMusic()

        if mouseMode {
            isStartingGame = false
        } else {
            tracker.start { [weak self] error in
                guard let self else { return }
                self.isStartingGame = false
                if let error {
                    self.handleCameraStartFailure(error)
                }
            }
        }
    }

    private func wire(_ scene: GameScene) {
        scene.bladeProvider = { [weak self] in self?.currentBladeSample() }
        scene.onCountdownTick = { [weak self] value in
            self?.audio.play(value == 1 ? "sfx_countdown" : "sfx_tick")
        }
        scene.onGameStart = { [weak self] in
            self?.audio.play("sfx_go")
        }
        scene.onSlice = { [weak self] _, combo in
            guard let self else { return }
            self.audio.play("sfx_slice")
            if combo >= 2 {
                self.audio.play("sfx_combo")
            }
#if DEBUG
            if self.debugCaptureSlices {
                let index = self.debugSliceCaptureCount
                self.debugSliceCaptureCount += 1
                // Catch the halves, juice, and slash just after the cut.
                DebugCapture.schedule(delay: 0.12) {
                    DebugCapture.captureWindow(name: String(format: "action-%02d", index))
                }
            }
#endif
        }
        scene.onBomb = { [weak self] in
            self?.audio.play("sfx_bomb")
        }
        scene.onLifeLost = { [weak self] in
            self?.audio.play("sfx_life_lost")
        }
        scene.onExtraLife = { [weak self] in
            self?.audio.play("sfx_life_gain")
        }
        scene.onGameOver = { [weak self] summary in
            self?.gameDidEnd(with: summary)
        }
    }

    private func handleCameraStartFailure(_ error: Error) {
        tracker.stop()
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "The camera could not start"
        alert.informativeText = (error.localizedDescription) +
            "\n\nYou can play with the mouse or fix Camera permission in System Settings."
        alert.addButton(withTitle: "Play with Mouse")
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Main Menu")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            startGame(mouseMode: true)
        } else if response == .alertSecondButtonReturn {
            openCameraSettings()
            showMenu()
        } else {
            showMenu()
        }
    }

    private func presentCameraDeniedAlert() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Camera access is needed for hand tracking"
        alert.informativeText = "Fruit Slice tracks your index fingertip on-device. " +
            "Nothing is recorded or sent anywhere. You can enable Camera access in System Settings " +
            "or play with the mouse instead."
        alert.addButton(withTitle: "Play with Mouse")
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            startGame(mouseMode: true)
        } else if response == .alertSecondButtonReturn {
            openCameraSettings()
        }
    }

    private func openCameraSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: Blade input

    private func currentBladeSample() -> BladeInputSample? {
        let now = CACurrentMediaTime()
        guard let scene = gameScene else { return nil }
#if DEBUG
        if debugAutoSlice {
            return debugAutoSliceSample(scene: scene, now: now)
        }
#endif
        if scene.mouseMode {
            guard mouseInside, let point = mousePoint else { return nil }
            guard skView.bounds.contains(point) else { return nil }
            return BladeInputSample(point: point, timestamp: now, present: true)
        }
        guard let sample = latestHandSample,
              sample.present,
              now - sample.timestamp < 0.28 else {
            return nil
        }

        let lookahead = min(max(now - sample.timestamp, 0), 0.033)
        let normalized = CGPoint(x: sample.indexTip.x + sample.velocity.x * lookahead,
                                 y: sample.indexTip.y + sample.velocity.y * lookahead)
        guard let mapped = mapHandPoint(normalized,
                                        videoSize: sample.videoSize,
                                        viewSize: scene.size) else {
            return nil
        }
        return BladeInputSample(point: mapped, timestamp: now, present: true)
    }

#if DEBUG
    /// Drives the blade back and forth across the nearest fruit so the real
    /// slice-detection, split, juice, and scorer paths run without a hand.
    private func debugAutoSliceSample(scene: GameScene, now: TimeInterval) -> BladeInputSample? {
        // Wait until fruit reaches the middle of the screen so captures show
        // the halves separating in the air instead of falling off-screen.
        let fruits = scene.debugFruitPositions
            .filter { $0.y > scene.size.height * 0.42 }
        guard !fruits.isEmpty else {
            debugSweepTarget = nil
            return BladeInputSample(point: CGPoint(x: scene.size.width * 0.5,
                                                   y: scene.size.height * 0.42),
                                    timestamp: now, present: true)
        }
        let reference = debugSweepTarget
            ?? CGPoint(x: scene.size.width * 0.5, y: scene.size.height * 0.5)
        let target = fruits.min { a, b in
            hypot(a.x - reference.x, a.y - reference.y) <
                hypot(b.x - reference.x, b.y - reference.y)
        } ?? fruits[0]
        debugSweepTarget = target

        // Alternate ends of a short diagonal inside the fruit's hit radius.
        // Each frame's segment crosses the fruit at well above slice speed.
        debugSweepSide *= -1
        let angle = -CGFloat.pi / 6
        let reach: CGFloat = 28
        let point = CGPoint(x: target.x + cos(angle) * reach * debugSweepSide,
                            y: target.y + sin(angle) * reach * debugSweepSide)
        return BladeInputSample(point: point, timestamp: now, present: true)
    }
#endif

    /// Maps an unmirrored, bottom-left Vision point into the mirrored, aspect-filled scene.
    private func mapHandPoint(_ point: CGPoint, videoSize: CGSize,
                              viewSize: CGSize) -> CGPoint? {
        guard viewSize.width > 1, viewSize.height > 1 else { return nil }
        let safeVideo = videoSize.width > 1 && videoSize.height > 1
            ? videoSize : CGSize(width: 16, height: 9)
        var x = 1.0 - point.x // camera preview is mirrored
        let y = point.y
        let videoAspect = safeVideo.width / safeVideo.height
        let viewAspect = viewSize.width / viewSize.height
        if viewAspect < videoAspect {
            // Aspect fill crops the sides of the video.
            let visible = viewAspect / videoAspect
            x = (x - (1.0 - visible) / 2.0) / visible
        } else if viewAspect > videoAspect {
            // Crop top/bottom (uncommon for a 16:9 camera in a wider window).
            let visible = videoAspect / viewAspect
            let adjustedY = (y - (1.0 - visible) / 2.0) / visible
            guard adjustedY >= 0, adjustedY <= 1 else { return nil }
            return CGPoint(x: x * viewSize.width, y: adjustedY * viewSize.height)
        }
        guard x >= 0, x <= 1, y >= 0, y <= 1 else { return nil }
        return CGPoint(x: x * viewSize.width, y: y * viewSize.height)
    }

    // MARK: Game over and persistence

    private func gameDidEnd(with summary: GameSummary) {
        guard !gameOverHandled else { return }
        gameOverHandled = true
        tracker.stop()
        audio.stopMusic()
        audio.play("sfx_game_over")

        let entry = ScoreEntry(
            playerName: settings.playerName,
            score: summary.score,
            difficulty: summary.difficulty,
            date: summary.date,
            maxCombo: summary.maxCombo,
            fruitsSliced: summary.fruitsSliced,
            accuracy: summary.accuracy)
        leaderboard.record(entry)
        let rank = leaderboard.rank(of: entry.id, difficulty: summary.difficulty)
        let entries = leaderboard.topPlayers(limit: 5, difficulty: summary.difficulty)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
            guard let self, self.gameScene?.hasEnded == true, self.overlayView == nil else { return }
            self.skView.isPaused = true
            self.skView.isHidden = true
            let gameOver = GameOverView(summary: summary,
                                        entries: entries,
                                        currentEntry: entry,
                                        rank: rank)
            gameOver.onReplay = { [weak self] in
                guard let self else { return }
                self.gameOverHandled = false
                self.startGame(mouseMode: self.settings.useMouseMode)
            }
            gameOver.onMenu = { [weak self] in
                self?.showMenu()
            }
            self.presentOverlay(gameOver)
        }
    }
}

extension RootViewController: FNHandTrackerDelegate {
    func handTracker(_ tracker: FNHandTracker, didUpdate sample: FNHandSample) {
        latestHandSample = sample
        handSampleCount += 1
        let now = CACurrentMediaTime()
        if now - handFPSWindowStart >= 1.0 {
            handFPS = Double(handSampleCount) / (now - handFPSWindowStart)
            handSampleCount = 0
            handFPSWindowStart = now
        }
        guard let scene = gameScene else { return }
        if sample.present {
            let width = Int(sample.videoSize.width)
            let height = Int(sample.videoSize.height)
            scene.trackingDebugInfo = String(
                format: "Camera %d×%d  •  pose %.1f fps  •  inference %.1f ms  •  confidence %.2f",
                width, height, handFPS, tracker.lastInferenceMilliseconds, sample.confidence)
        } else {
            scene.trackingDebugInfo = String(format: "Camera %d×%d  •  NO HAND  •  inference %.1f ms",
                                             Int(sample.videoSize.width),
                                             Int(sample.videoSize.height),
                                             tracker.lastInferenceMilliseconds)
        }
    }

    func handTracker(_ tracker: FNHandTracker, didFailWith error: Error) {
        NSLog("Fruit Slice hand tracker error: %@", error.localizedDescription)
    }
}
