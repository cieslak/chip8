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
                    shadowColor: UIColor(red: 232/255, green: 95/255, blue: 78/255, alpha: 0.5)),
        ScreenColor(name: "Cyberpunk",
                    backgroundColor: UIColor(red: 13/255, green: 2/255, blue: 33/255, alpha: 1),
                    foregroundColor: UIColor(red: 255/255, green: 0/255, blue: 228/255, alpha: 1),
                    shadowColor: UIColor(red: 255/255, green: 0/255, blue: 228/255, alpha: 0.6),
                    shadowBlur: 6.0),
        ScreenColor(name: "Phosphor Green",
                    backgroundColor: UIColor(red: 0/255, green: 12/255, blue: 0/255, alpha: 1),
                    foregroundColor: UIColor(red: 51/255, green: 255/255, blue: 0/255, alpha: 1),
                    shadowColor: UIColor(red: 51/255, green: 255/255, blue: 0/255, alpha: 0.7),
                    shadowBlur: 5.0),
        ScreenColor(name: "Amber CRT",
                    backgroundColor: UIColor(red: 15/255, green: 5/255, blue: 0/255, alpha: 1),
                    foregroundColor: UIColor(red: 255/255, green: 176/255, blue: 0/255, alpha: 1),
                    shadowColor: UIColor(red: 255/255, green: 176/255, blue: 0/255, alpha: 0.6),
                    shadowBlur: 5.0),
        ScreenColor(name: "Vaporwave",
                    backgroundColor: UIColor(red: 25/255, green: 6/255, blue: 51/255, alpha: 1),
                    foregroundColor: UIColor(red: 0/255, green: 255/255, blue: 239/255, alpha: 1),
                    shadowColor: UIColor(red: 0/255, green: 255/255, blue: 239/255, alpha: 0.5),
                    shadowBlur: 4.0),
        ScreenColor(name: "Frozen",
                    backgroundColor: UIColor(red: 200/255, green: 225/255, blue: 245/255, alpha: 1),
                    foregroundColor: UIColor(red: 20/255, green: 70/255, blue: 140/255, alpha: 1),
                    shadowColor: UIColor(red: 100/255, green: 180/255, blue: 255/255, alpha: 0.4),
                    shadowBlur: 4.0),
        ScreenColor(name: "Lava",
                    backgroundColor: UIColor(red: 20/255, green: 0/255, blue: 0/255, alpha: 1),
                    foregroundColor: UIColor(red: 255/255, green: 80/255, blue: 0/255, alpha: 1),
                    shadowColor: UIColor(red: 255/255, green: 40/255, blue: 0/255, alpha: 0.7),
                    shadowBlur: 6.0),
        ScreenColor(name: "Bubblegum",
                    backgroundColor: UIColor(red: 255/255, green: 200/255, blue: 221/255, alpha: 1),
                    foregroundColor: UIColor(red: 180/255, green: 30/255, blue: 100/255, alpha: 1),
                    shadowColor: UIColor(red: 220/255, green: 50/255, blue: 130/255, alpha: 0.4)),
        ScreenColor(name: "Midnight Ocean",
                    backgroundColor: UIColor(red: 5/255, green: 15/255, blue: 35/255, alpha: 1),
                    foregroundColor: UIColor(red: 0/255, green: 180/255, blue: 216/255, alpha: 1),
                    shadowColor: UIColor(red: 0/255, green: 150/255, blue: 200/255, alpha: 0.6),
                    shadowBlur: 5.0),
        ScreenColor(name: "Radioactive",
                    backgroundColor: UIColor(red: 0/255, green: 0/255, blue: 0/255, alpha: 1),
                    foregroundColor: UIColor(red: 180/255, green: 255/255, blue: 0/255, alpha: 1),
                    shadowColor: UIColor(red: 180/255, green: 255/255, blue: 0/255, alpha: 0.8),
                    shadowBlur: 8.0),
        ScreenColor(name: "Paper & Ink",
                    backgroundColor: UIColor(red: 242/255, green: 233/255, blue: 216/255, alpha: 1),
                    foregroundColor: UIColor(red: 40/255, green: 30/255, blue: 55/255, alpha: 1),
                    shadowColor: UIColor(red: 40/255, green: 30/255, blue: 55/255, alpha: 0.3),
                    shadowBlur: 2.0)
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
