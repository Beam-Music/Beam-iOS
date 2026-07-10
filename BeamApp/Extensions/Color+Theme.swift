import SwiftUI

extension Color {
    // 텍스트 색상
    static var primaryText: Color { AppTheme.primaryText }
    static var secondaryText: Color { AppTheme.secondaryText }
    
    // 배경 색상
    static var appBackground: Color { AppTheme.backgroundGradientTop }
    static var secondaryBackground: Color { AppTheme.surface }
    
    // 버튼 색상
    static var buttonBackground: Color { AppTheme.surface }
    static var buttonText: Color { AppTheme.primaryText }
    
    // 강조 색상
    static var appAccent: Color { AppTheme.primaryAccent }
}
