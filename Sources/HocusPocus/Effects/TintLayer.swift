import AppKit
import QuartzCore

final class TintLayer: CALayer {

    override init() {
        super.init()
        configure()
    }

    override init(layer: Any) {
        super.init(layer: layer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    private func configure() {
        backgroundColor = NSColor.clear.cgColor
        opacity = 0
    }

    func update(color: NSColor, opacity tintOpacity: Double, enabled: Bool) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if enabled {
            backgroundColor = color.cgColor
            opacity = Float(tintOpacity.clamped(to: 0...1))
        } else {
            opacity = 0
        }
        CATransaction.commit()
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
