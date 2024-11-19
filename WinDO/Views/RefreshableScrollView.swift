import SwiftUI

struct RefreshableScrollView<Content: View>: View {
    let onRefresh: (@escaping () -> Void) -> Void
    let content: Content
    
    @State private var refreshState: RefreshState = .waiting
    @State private var offset: CGFloat = 0
    
    init(
        onRefresh: @escaping (@escaping () -> Void) -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.onRefresh = onRefresh
        self.content = content()
    }
    
    var body: some View {
        ScrollView {
            ZStack(alignment: .top) {
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: OffsetPreferenceKey.self,
                        value: geometry.frame(in: .named("scrollView")).minY
                    )
                }
                .frame(height: 0)
                
                VStack(spacing: 0) {
                    RefreshHeader(refreshState: refreshState, offset: offset)
                        .offset(y: -50)
                    
                    content
                }
            }
        }
        .coordinateSpace(name: "scrollView")
        .onPreferenceChange(OffsetPreferenceKey.self) { offset in
            self.offset = offset
            
            switch refreshState {
            case .waiting:
                if offset > 50 {
                    refreshState = .primed
                }
            case .primed:
                if offset <= 0 {
                    refreshState = .refreshing
                    onRefresh {
                        withAnimation {
                            refreshState = .waiting
                        }
                    }
                }
            default:
                break
            }
        }
    }
}

// MARK: - Supporting Types
private enum RefreshState {
    case waiting
    case primed
    case refreshing
    
    var text: String {
        switch self {
        case .waiting:
            return "Pull to refresh"
        case .primed:
            return "Release to refresh"
        case .refreshing:
            return "Updating..."
        }
    }
}

private struct OffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct RefreshHeader: View {
    var refreshState: RefreshState
    var offset: CGFloat
    
    var body: some View {
        HStack {
            if refreshState == .refreshing {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            } else {
                Image(systemName: "arrow.down")
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(
                        min(Double(offset) * 3.0, 180.0)
                    ))
            }
            
            Text(refreshState.text)
                .font(.subheadline)
                .foregroundColor(.white)
        }
        .frame(height: 50)
    }
}

// MARK: - Preview
struct RefreshableScrollView_Previews: PreviewProvider {
    static var previews: some View {
        RefreshableScrollView(
            onRefresh: { done in
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    done()
                }
            }
        ) {
            Text("Content")
        }
    }
} 