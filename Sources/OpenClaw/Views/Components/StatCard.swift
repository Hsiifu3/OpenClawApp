import SwiftUI

struct StatCard: View {
    let title: String
    let value: String
    let subtext: String?
    let icon: String
    let color: Color
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline) // Subtitle style
                        .foregroundColor(.secondary)
                    
                    Text(value)
                        .font(.system(size: 28, weight: .bold, design: .rounded)) // Bigger font
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .padding(8)
                    .background(color.opacity(0.1))
                    .clipShape(Circle())
            }
            
            if let subtext = subtext {
                Text(subtext)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16) // Unified padding
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12) // Unified corner radius
        .overlay(
            // Colored left border effect via overlay alignment
            HStack {
                Rectangle()
                    .fill(color)
                    .frame(width: 4)
                Spacer()
            }
            .mask(RoundedRectangle(cornerRadius: 12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(isHovered ? 0.1 : 0.05), radius: isHovered ? 8 : 2, x: 0, y: isHovered ? 4 : 1)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}
