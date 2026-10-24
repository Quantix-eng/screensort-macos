import Foundation

enum KeyboardLayout: String, Codable, CaseIterable {
    case qwerty = "QWERTY"
    case azerty = "AZERTY"
    case dvorak = "DVORAK"

    var displayName: String {
        self.rawValue
    }

    static var savedLayout: KeyboardLayout {
        get {
            let rawValue = UserDefaults.standard.string(forKey: "keyboardLayout") ?? "QWERTY"
            return KeyboardLayout(rawValue: rawValue) ?? .qwerty
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "keyboardLayout")
        }
    }
}

// Keyboard layout key mappings
struct KeyboardLayoutMapping {
    static let qwerty: [UInt16: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 31: "O", 32: "U", 34: "I", 35: "P", 36: "Return",
        37: "L", 38: "J", 40: "K", 45: "N", 46: "M", 49: "Space", 51: "Delete",
        117: "Delete", 123: "←", 124: "→", 125: "↓", 126: "↑"
    ]
    
    static let azerty: [UInt16: String] = [
        0: "Q", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "W", 7: "X",
        8: "C", 9: "V", 11: "B", 12: "A", 13: "Z", 14: "E", 15: "R",
        16: "Y", 17: "T", 31: "O", 32: "U", 34: "I", 35: "P", 36: "Return",
        37: "L", 38: "J", 40: "K", 45: "N", 46: "M", 49: "Space", 51: "Delete",
        117: "Delete", 123: "←", 124: "→", 125: "↓", 126: "↑"
    ]

    static let dvorak: [UInt16: String] = [
        0: "A", 1: "O", 2: "E", 3: "U", 4: "D", 5: "I", 6: ";", 7: "Q",
        8: "J", 9: "K", 11: "N", 12: "'", 13: ",", 14: ".", 15: "P",
        16: "Y", 17: "F", 31: "R", 32: "G", 34: "C", 35: "L", 36: "Return",
        37: "S", 38: "H", 40: "T", 45: "B", 46: "M", 49: "Space", 51: "Delete",
        117: "Delete", 123: "←", 124: "→", 125: "↓", 126: "↑"
    ]
    
    static func getKeyName(keyCode: UInt16, layout: KeyboardLayout) -> String {
        let mapping: [UInt16: String] = {
            switch layout {
            case .azerty:
                return azerty
            case .dvorak:
                return dvorak
            case .qwerty:
                return qwerty
            }
        }()
        return mapping[keyCode] ?? "?"
    }
}
