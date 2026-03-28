import AppKit
import QuartzCore

enum GrayscaleFilter {

    /// Creates a CALayer that desaturates content beneath it via a compositing filter.
    static func makeDesaturationLayer() -> CALayer {
        let layer = CALayer()
        layer.compositingFilter = CIFilter(
            name: "CIColorControls",
            parameters: ["inputSaturation": 0.0]
        )
        layer.backgroundColor = NSColor.white.withAlphaComponent(0.001).cgColor
        return layer
    }

    /// Applies or removes grayscale from a target layer.
    static func setGrayscale(on layer: CALayer, enabled: Bool) {
        if enabled {
            layer.filters = [makeSaturationFilter()]
        } else {
            layer.filters = nil
        }
    }

    private static func makeSaturationFilter() -> CIFilter {
        let filter = CIFilter(
            name: "CIColorControls",
            parameters: ["inputSaturation": 0.0]
        )!
        filter.name = "grayscale"
        return filter
    }
}
