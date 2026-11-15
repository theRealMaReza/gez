/// Maths for game rules that must give bit-identical results on Mac, Windows
/// and Linux (needed for multiplayer lockstep and replays).
///
/// The system `sin`, `cos`, `atan2`, `pow`, `exp`... come from each platform's
/// own maths library and may differ in the last bit, which can flip a rule
/// (a flank check, a hill height) on one computer and not another. These
/// versions use only +, -, *, / and sqrt, which IEEE 754 makes exact
/// everywhere, in a fixed order. Accuracy is about 1e-15, far finer than any
/// rule needs.
public enum DetMath {
    public static let pi = 3.141592653589793
    public static let halfPi = 1.5707963267948966
    static let twoPi = 6.283185307179586
    static let sqrt3 = 1.7320508075688772
    static let tanPiOver12 = 0.2679491924311227
    static let piOver6 = 0.5235987755982988

    /// atan for 0 <= z <= tan(pi/12): odd power series to z^27.
    static func atanSmall(_ z: Double) -> Double {
        let z2 = z * z
        var term = z
        var sum = z
        var n = 1.0
        var sign = -1.0
        for _ in 0..<13 {
            term *= z2
            n += 2.0
            sum += sign * term / n
            sign = -sign
        }
        return sum
    }

    /// atan for 0 <= z <= 1.
    static func atanUnit(_ z: Double) -> Double {
        if z <= tanPiOver12 { return atanSmall(z) }
        // atan(z) = pi/6 + atan((z*sqrt3 - 1) / (sqrt3 + z))
        return piOver6 + atanSmall((z * sqrt3 - 1.0) / (sqrt3 + z))
    }

    public static func atan2(_ y: Double, _ x: Double) -> Double {
        let ax = x < 0 ? -x : x
        let ay = y < 0 ? -y : y
        if ax == 0 && ay == 0 { return 0 }
        var a: Double
        if ay > ax {
            a = halfPi - atanUnit(ax / ay)
        } else {
            a = atanUnit(ay / ax)
        }
        if x < 0 { a = pi - a }
        return y < 0 ? -a : a
    }

    public static func sin(_ x: Double) -> Double {
        // Reduce to [-pi, pi], then to [-pi/2, pi/2].
        var r = x - twoPi * (x / twoPi).rounded()
        if r > halfPi {
            r = pi - r
        } else if r < -halfPi {
            r = -pi - r
        }
        let r2 = r * r
        var term = r
        var sum = r
        for k in 1...11 {
            let d = Double((2 * k) * (2 * k + 1))
            term = -term * r2 / d
            sum += term
        }
        return sum
    }

    public static func cos(_ x: Double) -> Double {
        sin(x + halfPi)
    }

    /// Distance from (0,0) to (dx,dy): sqrt(dx*dx + dy*dy), no pow/hypot.
    public static func length(_ dx: Double, _ dy: Double) -> Double {
        (dx * dx + dy * dy).squareRoot()
    }
}
