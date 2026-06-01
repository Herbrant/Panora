// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

#if os(macOS)
import AppKit

extension View {
    /// Forces the arrow cursor while hovering, overriding SwiftUI's default
    /// interactive cursors on non-clickable rows. No-op off macOS.
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
