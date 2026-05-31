import SwiftUI

#if os(macOS)
import AppKit

extension View {
    func panoraArrowCursor() -> some View {
        onHover { isHovering in
            if isHovering {
                NSCursor.arrow.set()
            }
        }
    }
}
#else
extension View {
    func panoraArrowCursor() -> some View {
        self
    }
}
#endif
