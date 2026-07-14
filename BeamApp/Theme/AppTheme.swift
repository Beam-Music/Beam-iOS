import SwiftUI

enum AppTheme {
    static let primaryAccent = Color(red: 0.58, green: 0.35, blue: 1.0)
    static let secondaryAccent = Color(red: 1.0, green: 0.34, blue: 0.62)
    static let tertiaryAccent = Color(red: 0.2, green: 0.75, blue: 1.0)
    
    static let backgroundGradientTop = Color(red: 0.12, green: 0.08, blue: 0.2)
    static let backgroundGradientBottom = Color(red: 0.34, green: 0.12, blue: 0.24)
    
    static let onboardingGradientTop = Color.pink.opacity(0.7)
    static let onboardingGradientMiddle = Color.purple.opacity(0.7)
    static let onboardingGradientBottom = Color.orange.opacity(0.7)
    
    static let primaryText = Color.white
    static let secondaryText = Color.white.opacity(0.7)
    static let tertiaryText = Color.white.opacity(0.5)
    
    static let surface = Color.white.opacity(0.10)
    static let surfaceElevated = Color.white.opacity(0.16)
    static let surfaceOverlay = Color.black.opacity(0.78)
    static let separator = Color.white.opacity(0.12)
    static let destructive = Color(red: 1.0, green: 0.33, blue: 0.33)
    
    static let voiceButtonFill = Color.purple.opacity(0.55)
    static let preconvertButtonFill = Color.blue.opacity(0.4)
    static let conversionBannerStart = Color.purple.opacity(0.85)
    static let conversionBannerEnd = Color.indigo.opacity(0.85)
    
    static let mainGradient = LinearGradient(
        colors: [
            backgroundGradientTop,
            Color(red: 0.20, green: 0.11, blue: 0.32),
            backgroundGradientBottom
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let onboardingGradient = LinearGradient(
        colors: [onboardingGradientTop, onboardingGradientMiddle, onboardingGradientBottom],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

extension AppTheme {
    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }

    enum Radius {
        static let sm: CGFloat = 10
        static let md: CGFloat = 16
        static let lg: CGFloat = 22
    }
}

struct BeamScreenBackground: View {
    var body: some View {
        ZStack {
            AppTheme.mainGradient
            RadialGradient(
                colors: [AppTheme.tertiaryAccent.opacity(0.22), .clear],
                center: .topTrailing,
                startRadius: 24,
                endRadius: 360
            )
            RadialGradient(
                colors: [AppTheme.secondaryAccent.opacity(0.18), .clear],
                center: .bottomLeading,
                startRadius: 40,
                endRadius: 320
            )
        }
        .ignoresSafeArea()
    }
}

struct BeamSectionHeader: View {
    let title: String
    let subtitle: String?
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: AppTheme.Spacing.md)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.82))
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(actionTitle) \(title)")
            }
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
    }
}

struct BeamCardModifier: ViewModifier {
    var cornerRadius: CGFloat = AppTheme.Radius.md
    var fillOpacity: CGFloat = 0.10

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .background(Color.white.opacity(fillOpacity), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppTheme.separator, lineWidth: 1)
            }
    }
}

extension View {
    func beamCard(cornerRadius: CGFloat = AppTheme.Radius.md, fillOpacity: CGFloat = 0.10) -> some View {
        modifier(BeamCardModifier(cornerRadius: cornerRadius, fillOpacity: fillOpacity))
    }
}
