import AppKit
import CoreGraphics

/// Detects sustained mouse shake gestures (rapid back-and-forth movement held for a duration).
///
/// Unlike a simple "N direction changes" trigger, this requires the user to maintain
/// the shake for a configurable duration (default ~0.6s). This prevents accidental triggers
/// from normal mouse movement while still feeling responsive to intentional shakes.
///
/// ## Detection Algorithm
///
/// 1. Track mouse X positions with timestamps in a sliding window
/// 2. Count direction reversals (left-to-right or right-to-left) where each segment
///    exceeds a minimum pixel distance threshold
/// 3. When the reversal count reaches `requiredReversals`, start a "sustain timer"
/// 4. Only fire the action if the user continues shaking until the sustain timer completes
/// 5. If the shake stops (no reversal in 200ms), reset everything
///
/// ## Sensitivity Levels
///
/// Sensitivity (0.0 to 1.0) adjusts three parameters simultaneously:
/// - **Time window**: How long the shake history is kept (shorter = need faster shaking)
/// - **Minimum move distance**: How far each back-and-forth must travel (smaller = less effort)
/// - **Required reversals**: How many direction changes needed before sustain starts
///
/// | Sensitivity | Window | Min Move | Reversals | Feel |
/// |-------------|--------|----------|-----------|------|
/// | 0.2 (low)   | 0.4s   | 50px     | 6         | Vigorous sustained shake |
/// | 0.5 (mid)   | 0.6s   | 35px     | 5         | Moderate shake |
/// | 0.8 (high)  | 0.8s   | 20px     | 3         | Light shake |
@MainActor
final class ShakeDetector {
    typealias ShakeAction = @MainActor () -> Void

    private var onShake: ShakeAction?
    private var onPeek: ShakeAction?
    private var onPeekEnd: ShakeAction?
    private var monitor: Any?

    // Shake detection state
    private var positions: [(x: CGFloat, timestamp: TimeInterval)] = []
    private var reversalCount = 0
    private var lastDirection: Int = 0  // -1 left, 0 none, 1 right
    private var lastReversalTime: TimeInterval = 0
    private var isPeeking = false

    // Sustain state: shake must be held for this duration after threshold is met
    private var sustainStartTime: TimeInterval = 0
    private var isSustaining = false
    private let sustainDuration: TimeInterval = 0.3  // Must keep shaking for 300ms after threshold

    // Cooldown
    private let cooldownDuration: TimeInterval = 1.5
    private var lastShakeTime: TimeInterval = 0

    // Sensitivity-derived parameters (set via updateSensitivity)
    private var windowDuration: TimeInterval = 0.6
    private var minMoveDistance: CGFloat = 35
    private var requiredReversals: Int = 5

    var sensitivity: Double = 0.5 {
        didSet { updateSensitivityParams() }
    }

    init() {
        updateSensitivityParams()
    }

    func start(
        onShake: @escaping ShakeAction,
        onPeek: @escaping ShakeAction,
        onPeekEnd: @escaping ShakeAction
    ) {
        self.onShake = onShake
        self.onPeek = onPeek
        self.onPeekEnd = onPeekEnd

        monitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            MainActor.assumeIsolated {
                self?.handleMouseMove(event)
            }
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }

    private func updateSensitivityParams() {
        // Clamp to 0.1...1.0
        let s = min(max(sensitivity, 0.1), 1.0)

        // Higher sensitivity = wider window, smaller moves, fewer reversals
        windowDuration = 0.3 + s * 0.5           // 0.35s to 0.8s
        minMoveDistance = CGFloat(55 - s * 40)    // 51px down to 15px
        requiredReversals = Int(7 - s * 4)        // 6 down to 3
        if requiredReversals < 3 { requiredReversals = 3 }
    }

    private func handleMouseMove(_ event: NSEvent) {
        let now = CACurrentMediaTime()
        let x = NSEvent.mouseLocation.x  // Use screen coordinates for reliability

        positions.append((x: x, timestamp: now))

        // Prune old positions
        positions.removeAll { now - $0.timestamp > windowDuration }

        guard positions.count >= 3 else { return }

        // Detect direction change
        let prev = positions[positions.count - 2].x
        let dx = x - prev

        let moveThreshold = minMoveDistance / CGFloat(requiredReversals + 1)
        let direction: Int
        if dx > moveThreshold {
            direction = 1
        } else if dx < -moveThreshold {
            direction = -1
        } else {
            // Check if shake stopped during sustain
            if isSustaining && now - lastReversalTime > 0.2 {
                resetState()
            }
            return
        }

        // Count reversals
        if direction != lastDirection && lastDirection != 0 {
            reversalCount += 1
            lastReversalTime = now
        }
        lastDirection = direction

        // Phase 1: Accumulate enough reversals
        if !isSustaining && reversalCount >= requiredReversals {
            isSustaining = true
            sustainStartTime = now
        }

        // Phase 2: Check if sustain duration met
        if isSustaining && now - sustainStartTime >= sustainDuration {
            // Cooldown check
            if now - lastShakeTime < cooldownDuration {
                resetState()
                return
            }
            lastShakeTime = now
            resetState()

            // Fire action
            let shiftHeld = NSEvent.modifierFlags.contains(.shift)
            if shiftHeld {
                triggerPeek()
            } else {
                onShake?()
            }
        }
    }

    private func resetState() {
        reversalCount = 0
        lastDirection = 0
        isSustaining = false
        sustainStartTime = 0
        positions.removeAll()
    }

    private func triggerPeek() {
        guard !isPeeking else { return }
        isPeeking = true
        onPeek?()

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.isPeeking else { return }
                self.isPeeking = false
                self.onPeekEnd?()
            }
        }
    }
}
