//
//  SettingsViewController.swift
//  CHIP8
//
//  Created by Chris Cieslak on 2/3/26.
//
import UIKit

@objc protocol SettingsViewControllerDelegate {
    var incrementI: Bool { get set }
    var shiftVXVY: Bool {get set }
}

class SettingsViewController: UIViewController {
    
    weak var delegate: SettingsViewControllerDelegate?
    @IBOutlet var vxSwitch: UISwitch!
    @IBOutlet var iSwitch: UISwitch!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let delegate {
            vxSwitch.isOn = delegate.shiftVXVY
            iSwitch.isOn = delegate.incrementI
        }
    }
    
    
    @IBAction func exitTapped(sender: UIButton) {
        presentingViewController?.dismiss(animated: true)
    }

    @IBAction func vxSwitchToggled(sender: UISwitch) {
        if let delegate {
            delegate.shiftVXVY = vxSwitch.isOn
        }
    }
    
    @IBAction func iSwitchToggled(sender: UISwitch) {
        if let delegate {
            delegate.incrementI = iSwitch.isOn
        }
    }
    
 
}
