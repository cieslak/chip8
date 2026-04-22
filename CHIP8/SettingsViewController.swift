import UIKit
import SwiftUI

@MainActor
protocol SettingsViewControllerDelegate: AnyObject {
    var incrementI: Bool { get set }
    var shiftVXVY: Bool { get set }
    var colorChoices: [String] { get }
    func colorChanged()
}

class SettingsViewController: UIViewController {

    weak var delegate: SettingsViewControllerDelegate?
    @AppStorage("selectedColor") var selectedColor = 0

    @IBOutlet var vxSwitch: UISwitch!
    @IBOutlet var iSwitch: UISwitch!
    @IBOutlet var colorPicker: UIPickerView!

    override func viewDidLoad() {
        super.viewDidLoad()
        colorPicker.delegate = self
        colorPicker.dataSource = self
        colorPicker.selectRow(selectedColor, inComponent: 0, animated: false)
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

extension SettingsViewController: UIPickerViewDelegate {
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        delegate?.colorChoices[row]
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        selectedColor = row
        delegate?.colorChanged()
    }
}

extension SettingsViewController: UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        delegate?.colorChoices.count ?? 0
    }
}
