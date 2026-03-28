import AppKit
import QuartzCore

final class BlurView: NSVisualEffectView {

    private var customBlurRadius: CGFloat = 30.0
    private var isObservingLayers = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    private func configure() {
        blendingMode = .behindWindow
        material = .hudWindow  // Deeper blur baseline than .fullScreenUI
        state = .active
        autoresizingMask = [.width, .height]
    }

    func updateIntensity(_ amount: Double) {
        let clamped = CGFloat(min(max(amount, 0), 1))

        // Map 0-1 to blur radius 15-50pt for deep Monocle-like blur
        customBlurRadius = 15.0 + clamped * 35.0

        // Alpha always near-full so the overlay is solid
        alphaValue = 0.7 + clamped * 0.3
        applyCustomBlurRadius()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.applyCustomBlurRadius()
            self?.startObservingLayers()
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.applyCustomBlurRadius()
        }
    }

    private func applyCustomBlurRadius() {
        guard let rootLayer = layer else { return }
        applyBlurToLayerTree(rootLayer)
    }

    private func applyBlurToLayerTree(_ layer: CALayer) {
        // Check filters
        if let filters = layer.filters {
            for case let filter as NSObject in filters {
                applyRadiusIfBlurFilter(filter)
            }
        }

        // Check backgroundFilters (where the real blur often lives)
        if let bgFilters = layer.backgroundFilters {
            for case let filter as NSObject in bgFilters {
                applyRadiusIfBlurFilter(filter)
            }
        }

        // Recurse
        for sublayer in layer.sublayers ?? [] {
            applyBlurToLayerTree(sublayer)
        }
    }

    private func applyRadiusIfBlurFilter(_ filter: NSObject) {
        // Try setting inputRadius on anything that accepts it.
        // CAFilter, CIFilter, and other private filter types all use this key.
        let sel = NSSelectorFromString("setValue:forKey:")
        guard filter.responds(to: sel) else { return }

        // Check if it has an inputRadius property (blur filters do)
        if filter.responds(to: NSSelectorFromString("inputRadius"))
            || filter.responds(to: NSSelectorFromString("valueForKey:"))
        {
            // Try to read existing radius to confirm it's a blur filter
            if (filter as AnyObject).value(forKey: "inputRadius") as? NSNumber != nil {
                filter.setValue(NSNumber(value: Float(customBlurRadius)), forKey: "inputRadius")
            } else {
                // Try setting anyway
                filter.setValue(NSNumber(value: Float(customBlurRadius)), forKey: "inputRadius")
            }
        }
    }

    private func startObservingLayers() {
        guard !isObservingLayers, let rootLayer = layer else { return }
        isObservingLayers = true
        rootLayer.addObserver(self, forKeyPath: "sublayers", options: [.new], context: nil)
    }

    // swiftlint:disable:next block_based_kvo
    override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey: Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        if keyPath == "sublayers" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.applyCustomBlurRadius()
            }
        }
    }
}
