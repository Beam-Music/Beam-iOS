import SwiftUI

// VoiceInfo is defined in VoiceConversionClient.swift

struct VoiceSelectionSheet: View {
    let availableVoices: [VoiceInfo]
    @Binding var selectedVoice: VoiceInfo?
    let onVoiceSelected: (VoiceInfo) -> Void
    let onCancel: () -> Void
    
    @State private var searchText = ""
    
    var filteredVoices: [VoiceInfo] {
        if searchText.isEmpty {
            return availableVoices
        } else {
            return availableVoices.filter { voice in
                voice.name.localizedCaseInsensitiveContains(searchText) ||
                (voice.englishDescription?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                voice.englishCategory.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Handle
                Capsule()
                    .fill(Color.black.opacity(0.18))
                    .frame(width: 80, height: 8)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                
                // Header
                HStack {
                    Text("Select Voice")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Spacer()
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundColor(.purple)
                    .font(.system(size: 16, weight: .semibold))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.white.opacity(0.7))
                    TextField("Search voices", text: $searchText)
                        .foregroundColor(.white)
                        .padding(.vertical, 10)
                }
                .padding(.horizontal, 16)
                .background(Color.white.opacity(0.08))
                .cornerRadius(16)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                
                // Voice list
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredVoices) { voice in
                            VoiceRowView(voice: voice) {
                                onVoiceSelected(voice)
                            }
                        }
                    }
                }
                .frame(maxHeight: 400)
                
                Spacer(minLength: 0)
            }
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.black.opacity(0.85), Color.purple.opacity(0.7)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .cornerRadius(24)
            )
            .padding(.horizontal, 24)
            .padding(.vertical, 60)
        }
        .onTapGesture {
            onCancel()
        }
    }
}

struct VoiceRowView: View {
    let voice: VoiceInfo
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                VoiceAvatarView(voice: voice)
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(voice.name)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    if let description = voice.englishDescription {
                        Text(description)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(2)
                    }
                    
                    Text(voice.englishCategory)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.vertical, 9)
            .padding(.horizontal, 14)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
            .padding(.horizontal, 24)
            .padding(.vertical, 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    VoiceSelectionSheet(
        availableVoices: [
            VoiceInfo(id: "pNInz6obpgDQGcFmaJgB", name: "Adam", category: "Default", description: "Male voice", previewUrl: nil),
            VoiceInfo(id: "21m00Tcm4TlvDq8ikWAM", name: "Rachel", category: "Default", description: "Female voice", previewUrl: nil),
            VoiceInfo(id: "AZnzlk1XvdvUeBnXmlld", name: "Domi", category: "Default", description: "Female voice", previewUrl: nil)
        ],
        selectedVoice: .constant(nil),
        onVoiceSelected: { _ in },
        onCancel: {}
    )
} 