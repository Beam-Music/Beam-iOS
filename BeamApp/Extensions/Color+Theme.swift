import SwiftUI

extension Color {
    // Text colors
    static var primaryText: Color { AppTheme.primaryText }
    static var secondaryText: Color { AppTheme.secondaryText }
    
    // Background colors
    static var appBackground: Color { AppTheme.backgroundGradientTop }
    static var secondaryBackground: Color { AppTheme.surface }
    
    // Button colors
    static var buttonBackground: Color { AppTheme.surface }
    static var buttonText: Color { AppTheme.primaryText }
    
    // Accent colors
    static var appAccent: Color { AppTheme.primaryAccent }
}
