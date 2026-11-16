import UIKit

/// Four white corner brackets, like the aiming frame in Apple's own scanners.
/// (Translation: it's just decoration that tells people "aim the date at the middle".)
final class ViewfinderFrameView: UIView {

    private let shape = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        shape.strokeColor = UIColor.white.withAlphaComponent(0.9).cgColor
        shape.fillColor = nil
        shape.lineWidth = 4
        shape.lineCap = .round
        layer.addSublayer(shape)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Not used - we build screens in code") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let arm = min(bounds.width, bounds.height) * 0.18
        let rect = bounds.insetBy(dx: 2, dy: 2)
        let path = UIBezierPath()
        // top-left, top-right, bottom-right, bottom-left
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + arm))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + arm, y: rect.minY))
        path.move(to: CGPoint(x: rect.maxX - arm, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + arm))
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - arm))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - arm, y: rect.maxY))
        path.move(to: CGPoint(x: rect.minX + arm, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - arm))
        shape.path = path.cgPath
        shape.frame = bounds
    }
}
