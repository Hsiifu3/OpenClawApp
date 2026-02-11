import SwiftUI

struct InfoRow: View {
    let label: String
    let value: String
    var icon: String? = nil
    
    var body: some View {
        HStack {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundColor(.secondary)
                    .frame(width: 20)
            }
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .bold() // Use .bold() for value emphasis as requested in general style
                .foregroundColor(.primary)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
        .padding(.vertical, 4)
    }
}
