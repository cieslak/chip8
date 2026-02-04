//
//  ViewController.swift
//  CHIP8
//
//  Created by Chris Cieslak on 1/29/26.
//
import UniformTypeIdentifiers
import UIKit
import SwiftUI

class ViewController: UIViewController {

    let chip8 = Chip8Machine()
    @IBOutlet var display: Chip8DisplayView!
    @IBOutlet var runButton: UIButton!
    var buttons: [UIButton] =  []
    var isRunning = false
    @AppStorage("selectedColor") var selectedColor = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        display.selectedColor = self.selectedColor
        chip8.display = display
        chip8.delegate = self
        runButton.setImage(UIImage(systemName: "play.circle.fill"), for: .normal)
        for i in [1, 2, 3, 12, 4, 5, 6, 13, 7, 8, 9, 14, 10, 0, 11, 15] {
            let button = UIButton(type: .roundedRect)
            button.setTitle(String(i, radix: 16).uppercased(), for: .normal)
            button.tag = i
            button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 32)
            button.titleLabel?.textColor = .label
            if (i < 10) {
                button.backgroundColor = .systemGray3
            } else {
                button.backgroundColor = .systemGray
            }
            button.addTarget(self, action: #selector(buttonDown), for: .touchDown)
            button.addTarget(self, action: #selector(buttonUp), for: [.touchUpInside, .touchDragOutside])
            view.addSubview(button)
            buttons.append(button)
        }
        let screenWidth = view.bounds.width - 10
        let buttonWidth = screenWidth / 4
        var k = 0
        for i in 0..<4 {
            for j in 0..<4 {
                let button = buttons[k]
                let x = floor(CGFloat(j) * buttonWidth + 10)
                let y = floor(280 + CGFloat(i) * buttonWidth + 10)
                button.frame = CGRect(x: x, y: y, width: buttonWidth - 10, height: buttonWidth - 10)
                button.layer.cornerRadius = floor((buttonWidth - 10) / 2 -  1)
                button.clipsToBounds = true
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
    
    @IBAction func runTapped(sender: UIButton) {
        if !isRunning {
            runButton.setImage(UIImage(systemName: "stop.circle.fill"), for: .normal)
            chip8.start()
            isRunning = true
        } else {
            runButton.setImage(UIImage(systemName: "play.circle.fill"), for: .normal)
            chip8.stop()
            chip8.reset()
            runButton.isEnabled = false
            isRunning = false
        }
    }

    @IBAction func loadDocument(sender: Any) {
        guard let type = UTType("com.chip8.rom") else { return }
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [type])
        picker.delegate = self
        present(picker, animated: true)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        runButton.isEnabled = chip8.didLoad
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        if let destination = segue.destination as? UINavigationController, let root = destination.topViewController as? SettingsViewController {
            root.delegate = self
        }
    }
}

extension ViewController: Chip8Delegate {
    func loadStatusChanged() {
        isRunning = false
        runButton.setImage(UIImage(systemName: "play.circle.fill"), for: .normal)
        runButton.isEnabled = chip8.didLoad
    }
}

extension ViewController: SettingsViewControllerDelegate {
    func colorChanged() {
        display.selectedColor = selectedColor
        display.setNeedsDisplay()
    }
    
    var colorChoices: [String] {
        return display.colorChoices
    }
    
    var incrementI: Bool {
        get {
            chip8.incrementI
        }
        set {
            chip8.incrementI = newValue
        }
    }
    
    var shiftVXVY: Bool {
        get {
            chip8.shiftVXVY
        }
        set {
            chip8.shiftVXVY = newValue
        }
    }
}

extension ViewController: UIDocumentPickerDelegate {
    
    public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else {
                return
            }
        try? chip8.load(url: url)
        }
    
}

