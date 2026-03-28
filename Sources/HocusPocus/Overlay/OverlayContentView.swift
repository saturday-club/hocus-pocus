import AppKit
import QuartzCore

@MainActor
final class OverlayContentView: NSView {

    private let blurView = BlurView(frame: .zero)
    private let tintLayer = TintLayer()
    private var tintHostView: NSView?
    private var grainHostView: NSView?
    private var grainRenderer: GrainRenderer?
    private let screen: NSScreen

    // Mask caching
    private var cachedMaskFrames: [CGRect] = []
    private var cachedMode: FocusMode = .deep

    init(frame: NSRect, screen: NSScreen) {
        self.screen = screen
        super.init(frame: frame)
        wantsLayer = true
        layer?.masksToBounds = true

        setupBlur()
        setupTint()
        setupGrain()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    private func setupBlur() {
        blurView.frame = bounds
        addSubview(blurView)
    }

    private func setupTint() {
        // Use an NSView wrapper to ensure tint renders above NSVisualEffectView
        let tintHost = NSView(frame: bounds)
        tintHost.wantsLayer = true
        tintHost.autoresizingMask = [.width, .height]
        tintHost.layer?.addSublayer(tintLayer)
        tintLayer.frame = bounds
        addSubview(tintHost, positioned: .above, relativeTo: blurView)
        self.tintHostView = tintHost
    }

    private func setupGrain() {
        if let renderer = GrainRenderer() {
            self.grainRenderer = renderer
            renderer.metalLayer.frame = bounds
            renderer.metalLayer.opacity = 0

            // Overlay blend mode: gray > 0.5 lightens, < 0.5 darkens the blur beneath.
            // This is how Monocle's grain works -- it modulates existing colors in both directions.
            renderer.metalLayer.compositingFilter = "overlayBlendMode"

            let grainHost = NSView(frame: bounds)
            grainHost.wantsLayer = true
            grainHost.autoresizingMask = [.width, .height]
            grainHost.layer?.addSublayer(renderer.metalLayer)
            addSubview(grainHost, positioned: .above, relativeTo: tintHostView)
            self.grainHostView = grainHost
        }
    }

    override func layout() {
        super.layout()
        blurView.frame = bounds
        tintHostView?.frame = bounds
        tintLayer.frame = tintHostView?.bounds ?? bounds
        grainHostView?.frame = bounds
        grainRenderer?.metalLayer.frame = grainHostView?.bounds ?? bounds
        grainRenderer?.updateSize(bounds.size, scaleFactor: screen.backingScaleFactor)
    }

    func updateEffects(state: AppState) {
        blurView.updateIntensity(state.blurAmount)

        tintLayer.update(
            color: state.tintColor,
            opacity: state.tintOpacity,
            enabled: state.tintEnabled
        )

        // Grain: static render with overlay blend mode.
        // Shader outputs gray noise (full opacity). Layer opacity controls grain strength.
        // Overlay blend: gray > 0.5 lightens, < 0.5 darkens the blur beneath.
        if state.grainIntensity > 0.01 {
            // Map slider 0-1 to opacity 0-0.5 (0.5 is very strong grain)
            let grainOpacity = Float(state.grainIntensity * 0.5)
            grainRenderer?.metalLayer.opacity = grainOpacity
            grainRenderer?.start()  // Renders once (static)
        } else {
            grainRenderer?.metalLayer.opacity = 0
        }

        if let layer = self.layer {
            GrayscaleFilter.setGrayscale(on: layer, enabled: state.grayscaleEnabled)
        }
    }

    func updateFocusRegion(frames: [CGRect], mode: FocusMode) {
        let localFrames = frames.map { frame in
            MaskBuilder.convertToViewCoordinates(windowFrame: frame, screen: screen)
        }

        // Skip rebuild if nothing changed
        if localFrames == cachedMaskFrames && mode == cachedMode {
            return
        }
        cachedMaskFrames = localFrames
        cachedMode = mode

        if localFrames.isEmpty {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            layer?.mask = nil
            CATransaction.commit()
            return
        }

        let newMask = MaskBuilder.buildMask(
            overlayBounds: bounds,
            focusedFrames: localFrames,
            cornerRadius: 10.0,
            isAmbient: mode == .ambient
        )

        CATransaction.begin()
        CATransaction.setAnimationDuration(0.15)
        CATransaction.setAnimationTimingFunction(
            CAMediaTimingFunction(name: .easeOut)
        )
        layer?.mask = newMask
        CATransaction.commit()
    }

    /// Remove any mask -- used in deep mode where window ordering handles the cutout.
    func clearMask() {
        guard layer?.mask != nil else { return }
        cachedMaskFrames = []
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer?.mask = nil
        CATransaction.commit()
    }

    func teardown() {
        grainRenderer?.stop()
    }
}
