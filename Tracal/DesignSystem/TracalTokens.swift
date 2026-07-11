import SwiftUI
import UIKit

enum TracalColor {
    static let backgroundPrimary = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.055, green: 0.059, blue: 0.055, alpha: 1)
                : UIColor(red: 0.965, green: 0.961, blue: 0.945, alpha: 1)
        }
    )

    static let backgroundSecondary = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.102, green: 0.110, blue: 0.102, alpha: 1)
                : UIColor(red: 0.995, green: 0.992, blue: 0.980, alpha: 1)
        }
    )

    static let backgroundTertiary = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.145, green: 0.153, blue: 0.141, alpha: 1)
                : UIColor(red: 0.925, green: 0.925, blue: 0.894, alpha: 1)
        }
    )

    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary

    static let accent = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.595, green: 0.715, blue: 0.585, alpha: 1)
                : UIColor(red: 0.285, green: 0.410, blue: 0.275, alpha: 1)
        }
    )

    static let glassAccentVibrant = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.455, green: 0.785, blue: 0.475, alpha: 1)
                : UIColor(red: 0.220, green: 0.545, blue: 0.275, alpha: 1)
        }
    )

    static let accentForeground = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.045, green: 0.055, blue: 0.043, alpha: 1)
                : UIColor.white
        }
    )

    static let protein = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.835, green: 0.590, blue: 0.560, alpha: 1)
                : UIColor(red: 0.675, green: 0.315, blue: 0.285, alpha: 1)
        }
    )

    static let carbohydrate = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.825, green: 0.690, blue: 0.460, alpha: 1)
                : UIColor(red: 0.615, green: 0.440, blue: 0.195, alpha: 1)
        }
    )

    static let fat = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.530, green: 0.680, blue: 0.790, alpha: 1)
                : UIColor(red: 0.275, green: 0.475, blue: 0.615, alpha: 1)
        }
    )

    static let destructive = Color.red
}

enum TracalSpace {
    static let xSmall: CGFloat = 6
    static let small: CGFloat = 10
    static let medium: CGFloat = 16
    static let large: CGFloat = 24
    static let xLarge: CGFloat = 32
    static let section: CGFloat = 40
}

enum TracalRadius {
    static let small: CGFloat = 14
    static let medium: CGFloat = 22
    static let large: CGFloat = 30
}

enum TracalMetric {
    static let minimumTapTarget: CGFloat = 44
    static let contentMaxWidth: CGFloat = 620
}
