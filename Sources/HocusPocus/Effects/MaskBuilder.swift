import AppKit
import QuartzCore

enum MaskBuilder {

    static func buildMask(
        overlayBounds: CGRect,
        focusedFrames: [CGRect],
        cornerRadius: CGFloat = 10.0,
        isAmbient: Bool = false
    ) -> CALayer {
        if isAmbient {
            return buildGradientMask(overlayBounds: overlayBounds, focusedFrames: focusedFrames)
        }
        return buildSharpMask(
            overlayBounds: overlayBounds,
            focusedFrames: focusedFrames,
            cornerRadius: cornerRadius
        )
    }

    private static func buildSharpMask(
        overlayBounds: CGRect,
        focusedFrames: [CGRect],
        cornerRadius: CGFloat
    ) -> CAShapeLayer {
        let path = CGMutablePath()
        path.addRect(overlayBounds)

        for frame in focusedFrames {
            // Expand cutout by 4px in each direction to swallow shadow/border gaps
            let cutout = frame.insetBy(dx: -4, dy: -4)
            path.addRoundedRect(
                in: cutout,
                cornerWidth: cornerRadius,
                cornerHeight: cornerRadius
            )
        }

        let mask = CAShapeLayer()
        mask.path = path
        mask.fillRule = .evenOdd
        mask.frame = overlayBounds
        return mask
    }

    private static func buildGradientMask(
        overlayBounds: CGRect,
        focusedFrames: [CGRect]
    ) -> CALayer {
        let container = CALayer()
        container.frame = overlayBounds
        container.backgroundColor = NSColor.white.cgColor

        for frame in focusedFrames {
            let expansion: CGFloat = 250
            let gradientFrame = frame.insetBy(dx: -expansion, dy: -expansion)

            let gradientLayer = CAGradientLayer()
            gradientLayer.type = .radial
            gradientLayer.frame = gradientFrame
            gradientLayer.colors = [
                NSColor.black.cgColor,
                NSColor.black.withAlphaComponent(0.6).cgColor,
                NSColor.clear.cgColor
            ]
            gradientLayer.locations = [0.0, 0.35, 1.0]
            gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
            gradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)

            container.addSublayer(gradientLayer)
        }

        return container
    }

    /// Convert CG screen coordinates (top-left origin) to AppKit view-local (bottom-left origin).
    static func convertToViewCoordinates(
        windowFrame: CGRect,
        screen: NSScreen
    ) -> CGRect {
        let screenFrame = screen.frame
        guard let mainScreen = NSScreen.screens.first else { return windowFrame }
        let mainScreenHeight = mainScreen.frame.height

        // CG Y is from top of main display; AppKit Y is from bottom
        let appKitY = mainScreenHeight - windowFrame.origin.y - windowFrame.height

        let localX = windowFrame.origin.x - screenFrame.origin.x
        let localY = appKitY - screenFrame.origin.y

        return CGRect(
            x: localX,
            y: localY,
            width: windowFrame.width,
            height: windowFrame.height
        )
    }
}
