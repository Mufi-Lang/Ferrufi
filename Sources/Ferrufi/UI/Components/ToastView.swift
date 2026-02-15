import SwiftUI

public enum ToastType {
    case info
    case success
    case error
    case warning
    
    var color: Color {
        switch self {
        case .info: return .blue
        case .success: return .green
        case .error: return .red
        case .warning: return .orange
        }
    }
    
    var icon: String {
        switch self {
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        case .warning: return "exclamationmark.circle.fill"
        }
    }
}

public struct ToastMessage: Identifiable {
    public let id = UUID()
    public let message: String
    public let type: ToastType
    public let duration: Double
}

@MainActor
public class ToastManager: ObservableObject {
    public static let shared = ToastManager()
    
    @Published var currentToasts: [ToastMessage] = []
    
    private init() {}
    
    public func show(message: String, type: ToastType = .info, duration: Double = 3.0) {
        let toast = ToastMessage(message: message, type: type, duration: duration)
        withAnimation {
            currentToasts.append(toast)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            withAnimation {
                self.currentToasts.removeAll { $0.id == toast.id }
            }
        }
    }
}

struct ToastView: View {
    let toast: ToastMessage
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: toast.type.icon)
                .foregroundColor(toast.type.color)
            
            Text(toast.message)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(toast.type.color.opacity(0.3), lineWidth: 1)
        )
    }
}

public struct ToastOverlay: ViewModifier {
    @ObservedObject var manager = ToastManager.shared
    
    public func body(content: Content) -> some View {
        ZStack {
            content
            
            VStack {
                Spacer()
                ForEach(manager.currentToasts) { toast in
                    ToastView(toast: toast)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 10)
                        .allowsHitTesting(true) // Re-enable for the toast itself if we want clicks
                }
            }
            .padding(.bottom, 20)
            .ignoresSafeArea()
            .allowsHitTesting(false) // Disable for the container so scrolls pass through
        }
    }
}

public extension View {
    func toastOverlay() -> some View {
        self.modifier(ToastOverlay())
    }
}
