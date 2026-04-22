import UIKit

@MainActor
protocol Chip8DisplayDelegate: AnyObject, Sendable {
    func update(video: [UInt8])
    func set(displayType: DisplayType)
    var colorChoices: [String] { get }
}

class Chip8DisplayView: UIView, Chip8DisplayDelegate {

    struct ScreenColor {
        let name: String
        let backgroundColor: UIColor
        let foregroundColor: UIColor
        var shadowColor: UIColor? = nil
        var shadowBlur: CGFloat = 3.0
        var shadowOffset = CGSize(width: 2, height: 2)
    }

    var selectedColor = 0

    private var videoMemory = [UInt8](repeating: 0, count: 32 * 64)
    private var displayType = DisplayType.standard

    private let colors = [
        ScreenColor(name: "Standard",
                    backgroundColor: .white,
                    foregroundColor: .black),
        ScreenColor(name: "LCD",
                    backgroundColor: UIColor(red: 167/255, green: 154/255, blue: 153/255, alpha: 1),
                    foregroundColor: UIColor(red: 30/255, green: 2/255, blue: 1/255, alpha: 1),
                    shadowColor: UIColor(red: 30/255, green: 2/255, blue: 1/255, alpha: 0.5)),
        ScreenColor(name: "Gameboy",
                    backgroundColor: UIColor(red: 139/255, green: 172/255, blue: 15/255, alpha: 1),
                    foregroundColor: UIColor(red: 15/255, green: 56/255, blue: 15/255, alpha: 1),
                    shadowColor: UIColor(red: 15/255, green: 56/255, blue: 15/255, alpha: 0.5)),
        ScreenColor(name: "Autumn",
                    backgroundColor: UIColor(red: 243/255, green: 174/255, blue: 61/255, alpha: 1),
                    foregroundColor: UIColor(red: 158/255, green: 74/255, blue: 27/255, alpha: 1),
                    shadowColor: UIColor(red: 158/255, green: 74/255, blue: 27/255, alpha: 0.5)),
        ScreenColor(name: "Blue Backlight",
                    backgroundColor: UIColor(red: 34/255, green: 55/255, blue: 215/255, alpha: 1),
                    foregroundColor: UIColor(red: 163/255, green: 173/255, blue: 156/255, alpha: 1),
                    shadowColor: UIColor(red: 163/255, green: 173/255, blue: 156/255, alpha: 0.5)),
        ScreenColor(name: "Reverse Red Backlight",
                    backgroundColor: UIColor(red: 52/255, green: 10/255, blue: 13/255, alpha: 1),
                    foregroundColor: UIColor(red: 232/255, green: 95/255, blue: 78/255, alpha: 1),
                    shadowColor: UIColor(red: 232/255, green: 95/255, blue: 78/255, alpha: 0.5))
    ]

    lazy var colorChoices = colors.map { $0.name }

    func update(video: [UInt8]) {
        videoMemory = video
        setNeedsDisplay()
    }

    func set(displayType: DisplayType) {
        self.displayType = displayType
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        UIColor.black.setStroke()
        let color = colors[selectedColor]
        color.backgroundColor.setFill()
        let ctx = UIGraphicsGetCurrentContext()
        ctx?.fill(bounds)
        ctx?.stroke(bounds)
        color.foregroundColor.setFill()
        let w = bounds.size.width / displayType.size.width
        let h = bounds.size.height / displayType.size.height
        var i = 0
        ctx?.saveGState()
        if let shadowColor = color.shadowColor {
            ctx?.setShadow(offset: color.shadowOffset, blur: color.shadowBlur, color: shadowColor.cgColor)
        }
        for row in 0..<Int(displayType.size.height) {
            for col in 0..<Int(displayType.size.width) {
                if i >= videoMemory.count { return }
                if videoMemory[i] > 0 {
                    let x = w * CGFloat(col)
                    let y = h * CGFloat(row)
                    let pixelRect = CGRect(x: x, y: y, width: w, height: h)
                    ctx?.fill(pixelRect)
                }
                i = i + 1
            }
        }
        ctx?.restoreGState()
    }
}
