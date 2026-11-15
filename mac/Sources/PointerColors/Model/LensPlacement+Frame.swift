import CoreGraphics

/// Where each placement puts the lens. Everything is in points on one display, from its top left,
/// with y growing downward, as the pointer moves over it.
extension LensPlacement {
    /// Points between the pointer and the lens.
    static let gap: CGFloat = 12
    /// Points between the lens and the display's edges.
    static let margin: CGFloat = 8

    /// The lens's frame for the pointer at `pointer` on a display of `screen` size.
    func frame(pointer: CGPoint, lens: CGSize, screen: CGSize) -> CGRect {
        let y = Self.verticalY(pointer: pointer, lens: lens)
        switch self {
        case .onPointer:
            return CGRect(origin: CGPoint(x: pointer.x - lens.width / 2, y: pointer.y - lens.height / 2), size: lens)
        case .quadrants:
            let x = Self.sideX(pointer: pointer, lens: lens, toRight: pointer.x < screen.width / 2)
            return Self.kept(CGRect(origin: CGPoint(x: x, y: y), size: lens), in: screen)
        case .edgeBands:
            let x = Self.bandX(pointer: pointer, lens: lens, screen: screen)
            return Self.kept(CGRect(origin: CGPoint(x: x, y: y), size: lens), in: screen)
        case .slideAndFlip:
            return Self.kept(CGRect(origin: CGPoint(x: pointer.x - lens.width / 2, y: y), size: lens), in: screen)
        case .orbit:
            return Self.orbitFrame(pointer: pointer, lens: lens, screen: screen)
        }
    }

    /// Whether the lens stays inside the display; only On the pointer goes past its edges, as it always has.
    var staysOnScreen: Bool { self != .onPointer }

    /// `rect` moved inside a display of `screen` size, `margin` points from its edges.
    static func kept(_ rect: CGRect, in screen: CGSize) -> CGRect {
        let x = max(margin, min(rect.minX, screen.width - margin - rect.width))
        let y = max(margin, min(rect.minY, screen.height - margin - rect.height))
        return CGRect(origin: CGPoint(x: x, y: y), size: rect.size)
    }

    /// Above the pointer when the lens fits there, below it otherwise.
    private static func verticalY(pointer: CGPoint, lens: CGSize) -> CGFloat {
        let above = pointer.y - gap - lens.height
        return above >= margin ? above : pointer.y + gap
    }

    /// Beside the pointer, to its right or its left.
    private static func sideX(pointer: CGPoint, lens: CGSize, toRight: Bool) -> CGFloat {
        toRight ? pointer.x + gap : pointer.x - gap - lens.width
    }

    /// Centred on the pointer, or beside it, away from a side edge it would go past.
    private static func bandX(pointer: CGPoint, lens: CGSize, screen: CGSize) -> CGFloat {
        if pointer.x - lens.width / 2 < margin { return sideX(pointer: pointer, lens: lens, toRight: true) }
        if pointer.x + lens.width / 2 > screen.width - margin { return sideX(pointer: pointer, lens: lens, toRight: false) }
        return pointer.x - lens.width / 2
    }

    /// Up in open space, leaning toward the middle; turning through sideways to down across a band
    /// at the top as tall as three quarters of the lens.
    private static func orbitFrame(pointer: CGPoint, lens: CGSize, screen: CGSize) -> CGRect {
        let top = margin + gap + lens.height
        let ramp = lens.height * 0.75
        let up = -min(max((pointer.y - top + ramp / 2) / ramp, -1), 1)
        let across = (screen.width / 2 - pointer.x) / (screen.width / 2) * 0.9
        let length = max(hypot(across, up), 0.0001)
        let direction = CGVector(dx: across / length, dy: up / length)
        let reach = edgeDistance(of: lens, along: direction) + gap
        let centre = CGPoint(x: pointer.x + direction.dx * reach, y: pointer.y + direction.dy * reach)
        let origin = CGPoint(x: centre.x - lens.width / 2, y: centre.y - lens.height / 2)
        let frame = kept(CGRect(origin: origin, size: lens), in: screen)
        // Kept off the top edge, it can land back on the pointer: slide it sideways just clear of it.
        guard frame.contains(pointer) else { return frame }
        let x = sideX(pointer: pointer, lens: lens, toRight: across >= 0)
        return kept(CGRect(origin: CGPoint(x: x, y: frame.minY), size: lens), in: screen)
    }

    /// How far a lens's edge is from its centre along `direction`, a unit vector.
    private static func edgeDistance(of lens: CGSize, along direction: CGVector) -> CGFloat {
        let across = direction.dx == 0 ? .infinity : lens.width / 2 / abs(direction.dx)
        let down = direction.dy == 0 ? .infinity : lens.height / 2 / abs(direction.dy)
        return min(across, down)
    }
}
