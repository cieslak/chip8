//
//  Chip8DisplayView.swift
//  CHIP8
//
//  Created by Chris Cieslak on 1/30/26.
//

import UIKit

class Chip8DisplayView: UIView, Chip8DisplayDelegate {
   
    private var videoMemory = [UInt8](repeating: 0, count: 32 * 64)
    private let lightGreen = UIColor(red: 139/255, green: 172/255, blue: 15/255, alpha: 1)
    private let darkGreen = UIColor(red: 15/255, green: 56/255, blue: 15/255, alpha: 1)
    private let shadowColor = UIColor(red: 15/255, green: 56/255, blue: 15/255, alpha: 0.5)
    private let shadowBlur: CGFloat = 3.0
    private let shadowOffset = CGSize(width: 2, height: 2)
    
    func update(video: [UInt8]) {
        videoMemory = video
        setNeedsDisplay()
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        lightGreen.setFill()
        let ctx = UIGraphicsGetCurrentContext()
        ctx?.fill(bounds)
        darkGreen.setFill()
        let w = bounds.size.width / 64
        let h = bounds.size.height / 32
        var i = 0
        ctx?.saveGState()
        ctx?.setShadow(offset: shadowOffset, blur: shadowBlur, color: shadowColor.cgColor)
        for row in 0..<32 {
            for col in 0..<64 {
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
