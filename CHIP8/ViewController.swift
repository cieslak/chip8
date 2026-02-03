//
//  ViewController.swift
//  CHIP8
//
//  Created by Chris Cieslak on 1/29/26.
//

import UIKit

class ViewController: UIViewController {

    let chip8 = Chip8Machine()
    @IBOutlet var display: Chip8DisplayView!
    var buttons: [UIButton] =  []

    override func viewDidLoad() {
        super.viewDidLoad()
        chip8.display = display
        // Do any additional setup after loading the view.
        for i in [1, 2, 3, 12, 4, 5, 6, 13, 7, 8, 9, 14, 10, 0, 11, 15] {
            let button = UIButton(type: .roundedRect)
            button.setTitle(String(i, radix: 16), for: .normal)
            button.tag = i
            button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 32)
            button.addTarget(self, action: #selector(buttonDown), for: .touchDown)
            button.addTarget(self, action: #selector(buttonUp), for: [.touchUpInside, .touchDragOutside])
            view.addSubview(button)
            buttons.append(button)
        }
        let screenWidth = view.bounds.width
        let buttonWidth = screenWidth / 4
        var k = 0
        for i in 0..<4 {
            for j in 0..<4 {
                let button = buttons[k]
                let x = CGFloat(j) * buttonWidth
                let y = 300 + CGFloat(i) * buttonWidth
                button.frame = CGRect(x: x, y: y, width: buttonWidth, height: buttonWidth)
                k = k + 1
            }
        }
    }
    
    @objc func buttonDown(sender: UIButton) {
        chip8.set(key: sender.tag, state: true)
    }
    
    @objc func buttonUp(sender: UIButton) {
        chip8.set(key: sender.tag, state: false)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        chip8.start()
    }
}

