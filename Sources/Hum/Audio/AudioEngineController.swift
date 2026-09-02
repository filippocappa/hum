import AVFoundation
import AppKit
import Combine
import KeyboardShortcuts
import SwiftUI

/// Focus-session lengths offered in the bottom chip row.
enum FocusDuration: Int, CaseIterable, Identifiable {
    case continuous = 0
    case short = 25
    case medium = 45
    case long = 90

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .continuous: return "∞"
        default: return "\(rawValue)m"
        }
    }

    var seconds: TimeInterval? {
        self == .continuous ? nil : TimeInterval(rawValue * 60)
    }
}

/// Owns the `AVAudioEngine` graph, the parameter bridge to `NoiseDSP`, the
/// focus timer, and sleep/wake safety.
@MainActor
final class AudioEngineController: ObservableObject {

    /// Single instance, held outside the SwiftUI graph on purpose. If the App
    /// stores this as `@StateObject`, the *Scene* subscribes to it, and every
    /// published change — a volume drag at pointer rate — re-evaluates the
    /// scene body and churns the status item. Only the popover should observe.
    static let shared = AudioEngineController()


    // MARK: Published UI state

    @Published private(set) var isPlaying = false {
        didSet { menuBar.update(isPlaying: isPlaying) }
    }

    /// Drives the menu bar label alone, so a slider drag cannot reach it.
    let menuBar = MenuBarState()

    /// High-frequency visual signal, kept off this object so it cannot
    /// invalidate the menu bar label. See `VisualizerState`.
    let visuals = VisualizerState()

    /// Countdown, likewise on its own observable.
    let focus = FocusTimerState()

    /// Set by the popover's appear/disappear. Nothing visual is computed or
    /// published while the window is shut — there is no one to see it.
    var isPopoverVisible = false {
        didSet {
            guard isPopoverVisible != oldValue else { return }
            isPopoverVisible ? startVisualPolling() : stopVisualPolling()
        }
    }

    @Published var volume: Double = 0.55 {
        didSet {
            // A drag should track the pointer, not crescendo behind it.
            if isPlaying { dsp.rampSeconds = Self.sliderRamp }
            dsp.targetVolume = Float(volume)
        }
    }

    /// 0…1 warmth position, mapped exponentially onto 180 Hz…18 kHz.
    @Published var warmth: Double = 0.5 {
        didSet {
            dsp.cutoffHz = Self.cutoff(for: warmth)
            dsp.warmthNorm = Float(warmth)
        }
    }

    @Published var profile: NoiseProfile = .white {
        didSet { dsp.profileIndex = profile.dspIndex }
    }

    @Published var duration: FocusDuration = .continuous {
        didSet {
            // Choosing a duration starts a fresh session; it never resumes a
            // half-finished one.
            pausedRemaining = nil
            if isPlaying { startFocusTimer() }
            else { focus.update(seconds: duration.seconds.map { Int($0) }) }
        }
    }

    // MARK: Engine

    private let engine = AVAudioEngine()
    private var dsp: NoiseDSP
    private var sourceNode: AVAudioSourceNode?

    private var didBootstrap = false
    private var focusDeadline: Date?
    /// Time left when a session was paused, so resuming continues from there
    /// rather than restarting the full duration.
    private var pausedRemaining: TimeInterval?
    private var tickTimer: Timer?
    private var visualTimer: Timer?
    private var stopWorkItem: DispatchWorkItem?
    /// Set when the system puts us to sleep mid-playback so wake can restore it.
    private var wasPlayingBeforeSleep = false

    /// A timed session ends on a longer, gentler fade than a manual pause.
    private static let expiryFadeSeconds: TimeInterval = 3.0

    /// Crescendo on play, decrescendo on pause, and a short glide for slider drags.
    /// These are pole durations, not audible ones: the squared volume taper makes
    /// the heard fade shorter than the parameter, so both are tuned against
    /// measured output (≈800 ms in, ≈500 ms out). See `Tools/measure.swift`.
    private static let fadeInSeconds: TimeInterval = 0.92
    private static let fadeOutSeconds: TimeInterval = 1.0
    private static let sliderRamp: Float = 0.03

    /// Deliberately cheap. This runs while the App value is being created,
    /// before `NSApplication.run`, so it must not touch the audio HAL, TCC, or
    /// the notification centre: blocking here delays the run loop coming up and
    /// leaves the status item without its click handler attached.
    private init() {
        dsp = NoiseDSP(sampleRate: Self.fallbackSampleRate)
        applyParameters()
    }

    /// Everything the launch path cannot afford. Called once from
    /// `applicationDidFinishLaunching`, i.e. after AppKit is running.
    func bootstrap() {
        guard !didBootstrap else { return }
        didBootstrap = true

        let reported = engine.outputNode.outputFormat(forBus: 0).sampleRate
        let rate = reported > 0 ? reported : Self.fallbackSampleRate
        if rate != Self.fallbackSampleRate {
            // Rebuild at the device's real rate before the graph captures it.
            dsp = NoiseDSP(sampleRate: rate)
            applyParameters()
        }

        buildGraph(sampleRate: rate)
        observeSleepWake()
        // Carbon hotkey registration — no Accessibility permission, and it works
        // immediately without the re-arm dance a global event monitor needed.
        KeyboardShortcuts.onKeyUp(for: .togglePlayPause) { [weak self] in
            self?.toggle()
        }
    }

    private static let fallbackSampleRate: Double = 48_000

    private func applyParameters() {
        dsp.targetVolume = 0
        dsp.profileIndex = profile.dspIndex
        dsp.cutoffHz = Self.cutoff(for: warmth)
        dsp.warmthNorm = Float(warmth)
    }

    // MARK: Graph

    private func buildGraph(sampleRate: Double) {
        // Mono source, upmixed to the hardware layout by the mixer.
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return }

        let dsp = self.dsp
        let node = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let frames = Int(frameCount)

            guard let first = buffers.first?.mData?.assumingMemoryBound(to: Float.self) else {
                return noErr
            }
            dsp.render(into: first, frames: frames)

            // Duplicate into any additional channels the device asked for.
            for extra in buffers.dropFirst() {
                if let dest = extra.mData {
                    memcpy(dest, first, frames * MemoryLayout<Float>.size)
                }
            }
            return noErr
        }

        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 1.0
        sourceNode = node
    }

    // MARK: Transport

    func toggle() { isPlaying ? stop() : start() }

    func start() {
        stopWorkItem?.cancel()
        stopWorkItem = nil

        if !engine.isRunning {
            dsp.reset()
            engine.prepare()
            do {
                try engine.start()
            } catch {
                NSLog("Hum: audio engine failed to start — \(error.localizedDescription)")
                return
            }
        }

        // Crescendo in from silence.
        dsp.rampSeconds = Float(Self.fadeInSeconds)
        dsp.targetVolume = Float(volume)
        isPlaying = true
        if isPopoverVisible { startVisualPolling() }
        startFocusTimer()
    }

    /// Ramps the gain to zero, then tears the engine down once the tail has drained.
    func stop(fadeSeconds: TimeInterval? = nil) {
        guard isPlaying || engine.isRunning else { return }

        let fade = fadeSeconds ?? Self.fadeOutSeconds
        dsp.rampSeconds = Float(fade)
        dsp.targetVolume = 0
        isPlaying = false
        // Freeze the countdown where it stands so play resumes, not restarts.
        if let focusDeadline {
            pausedRemaining = max(0, focusDeadline.timeIntervalSinceNow)
        }
        cancelFocusTimer()

        // Tear the engine down only once the decrescendo has fully drained;
        // the margin covers the tail beyond three time constants.
        let work = DispatchWorkItem { [weak self] in
            guard let self, !self.isPlaying else { return }
            self.engine.pause()
            // Pausing strands the gain wherever the ramp had reached, so zero it
            // explicitly and stand the visualiser down with it.
            self.dsp.silence()
            self.visuals.reset()
            self.stopVisualPolling()
        }
        stopWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + fade + 0.25, execute: work)
    }

    // MARK: Focus timer

    private func startFocusTimer() {
        // Resume from a paused session if there is one, otherwise start fresh.
        let resumeFrom = pausedRemaining
        cancelFocusTimer()
        pausedRemaining = nil

        guard let seconds = resumeFrom ?? duration.seconds else {
            focus.update(seconds: nil)
            return
        }
        focusDeadline = Date().addingTimeInterval(seconds)
        focus.update(seconds: Int(seconds.rounded(.up)))

        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        tickTimer = timer
    }

    private func tick() {
        guard let deadline = focusDeadline else { return }
        let left = deadline.timeIntervalSinceNow
        if left <= 0 {
            focus.update(seconds: 0)
            expireSession()
        } else {
            focus.update(seconds: Int(left.rounded(.up)))
        }
    }

    private func cancelFocusTimer() {
        tickTimer?.invalidate()
        tickTimer = nil
        focusDeadline = nil
        // Hold a frozen session at its remaining time; otherwise show the full
        // duration the picker is set to.
        if let pausedRemaining {
            focus.update(seconds: Int(pausedRemaining.rounded(.up)))
        } else {
            focus.update(seconds: duration.seconds.map { Int($0) })
        }
    }

    /// The session ran out: fade the audio gently, then hand the card back to
    /// its idle picker once the tail has actually gone.
    private func expireSession() {
        pausedRemaining = nil
        stop(fadeSeconds: Self.expiryFadeSeconds)
        // stop() resets the display to the full duration via cancelFocusTimer;
        // hold it at zero instead, so the countdown does not jump back up while
        // the audio is still fading out.
        focus.update(seconds: 0)
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.expiryFadeSeconds + 0.25) { [weak self] in
            guard let self, !self.isPlaying else { return }
            self.duration = .continuous
        }
    }

    /// Cancels a running session from the UI, restoring the duration picker.
    /// Audio keeps playing; only the session ends.
    func cancelSession() {
        pausedRemaining = nil
        duration = .continuous
    }

    // MARK: Visualiser polling

    /// Runs only while the popover is open *and* there is still gain to show.
    /// Once the fade-out has drained with the transport stopped, it tears itself
    /// down rather than idling at 30 Hz.
    private func startVisualPolling() {
        stopVisualPolling()
        visuals.update(gain: dsp.currentGain)

        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                guard NSApp.windows.contains(where: { $0.isVisible }) else {
                    self.isPopoverVisible = false
                    return
                }
                self.visuals.update(gain: self.dsp.currentGain)
                if !self.isPlaying && (self.dsp.isSilent || !self.engine.isRunning) {
                    self.visuals.reset()
                    self.stopVisualPolling()
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        visualTimer = timer
    }

    private func stopVisualPolling() {
        visualTimer?.invalidate()
        visualTimer = nil
    }

    // MARK: Sleep / wake

    private func observeSleepWake() {
        let center = NSWorkspace.shared.notificationCenter

        center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.handleSleep() }
        }
        center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.handleWake() }
        }
    }

    private func handleSleep() {
        wasPlayingBeforeSleep = isPlaying
        guard isPlaying else { return }
        // Hard stop: the render thread must not be left holding the device
        // across a sleep transition, and the timer is paused with it.
        dsp.rampSeconds = Self.sliderRamp
        dsp.targetVolume = 0
        isPlaying = false
        if let focusDeadline {
            pausedRemaining = max(0, focusDeadline.timeIntervalSinceNow)
        }
        cancelFocusTimer()
        engine.pause()
        dsp.silence()
        visuals.reset()
        stopVisualPolling()
    }

    private func handleWake() {
        guard wasPlayingBeforeSleep else { return }
        wasPlayingBeforeSleep = false
        // The output device may have changed identity across sleep; a reset
        // forces the graph to re-resolve it before we start again.
        engine.reset()
        start()
    }

    // MARK: Helpers

    /// Exponential map so the slider's low end has usable resolution.
    private static func cutoff(for warmth: Double) -> Float {
        // Floor raised from 180 Hz: the master filter stacks on top of each
        // profile's own shaping, and below ~300 Hz that combination reads as
        // broken rather than warm.
        let low = 300.0, high = 18_000.0
        // warmth 1.0 = fully open / bright, 0.0 = heavily filtered / warm.
        return Float(low * pow(high / low, warmth))
    }


}
