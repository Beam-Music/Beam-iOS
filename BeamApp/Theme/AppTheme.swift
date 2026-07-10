import SwiftUI

enum AppTheme {
    static let primaryAccent = Color.purple
    static let secondaryAccent = Color.pink
    
    static let backgroundGradientTop = Color.purple.opacity(0.7)
    static let backgroundGradientBottom = Color.pink.opacity(0.5)
    
    static let onboardingGradientTop = Color.pink.opacity(0.7)
    static let onboardingGradientMiddle = Color.purple.opacity(0.7)
    static let onboardingGradientBottom = Color.orange.opacity(0.7)
    
    static let primaryText = Color.white
    static let secondaryText = Color.white.opacity(0.7)
    static let tertiaryText = Color.white.opacity(0.5)
    
    static let surface = Color.white.opacity(0.08)
    static let surfaceElevated = Color.white.opacity(0.12)
    static let surfaceOverlay = Color.black.opacity(0.78)
    
    static let voiceButtonFill = Color.purple.opacity(0.55)
    static let preconvertButtonFill = Color.blue.opacity(0.4)
    static let conversionBannerStart = Color.purple.opacity(0.85)
    static let conversionBannerEnd = Color.indigo.opacity(0.85)
    
    static let mainGradient = LinearGradient(
        colors: [backgroundGradientTop, backgroundGradientBottom],
        startPoint: .top,
        endPoint: .bottom
    )
    
    static let onboardingGradient = LinearGradient(
        colors: [onboardingGradientTop, onboardingGradientMiddle, onboardingGradientBottom],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
