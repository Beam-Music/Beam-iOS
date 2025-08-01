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
                (voice.description?.localizedCaseInsensitiveContains(searchText) ?? false)
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
                    Text("음성 선택")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Spacer()
                    Button("취소") {
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
                    TextField("음성 검색", text: $searchText)
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
            HStack(spacing: 16) {
                // Voice icon
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.3))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "person.wave.2.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(voice.name)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    if let description = voice.description {
                        Text(description)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(2)
                    }
                    
                    Text(voice.category)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
            .padding(.horizontal, 24)
            .padding(.vertical, 4)
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