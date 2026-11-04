import SwiftUI
import UIKit

/// The website's flowing-line background (public/assets/js/motion.js + app.css `.bg-lines`), ported to a Canvas:
/// the same four SVG paths and dash rhythms, dashes streaming along the lines with scroll (parallax) plus a slow idle drift.
/// Brand amber at low opacity on the solid surface; capped at 30 fps (15 in Low Power Mode); static under Reduce Motion;
/// paused when the app is not active. Cards sit on top as solid surfaces, so text contrast is unaffected.
enum FlowingLinesData {
    static let viewBox = CGSize(width: 740, height: 2000)
    static let lines: [(path: String, width: CGFloat, dash: [CGFloat])] = [
        ("m 106,45h 375c 114,0 226,128 226,235v 236c 0,136 -122,222 -224,221l -182,-2c -89,1 -141,42 -142,158l -2,204c -1,117 37,173 134,173h 186c 110,-3 230,111 230,220v 242c 0,113 -125,225 -248,225H 105", 15, [16, 46, 110, 46, 16, 46, 280, 46, 16, 46, 140, 46, 16, 20000]),
        ("m 33,85h 444c 96,0 190,107 190,201v 224c 0,116 -98,188 -190,187l -192,-2c -92,0 -166,75 -166,168v 278c 0,94 74,169 166,169h 194c 92,0 188,94 188,188v 228c 0,94 -104,191 -214,191H 105", 28, [30, 56, 110, 56, 30, 56, 280, 56, 30, 56, 140, 56, 30, 20000]),
        ("m 155,127h 308c 94,0 162,86 162,177v 178c 0,109 -50,174 -166,173L 277,653C 158,653 77,762 77,849v 302c 0,118 107,196 180,197l 204,4c 92,0 164,67 164,160v 200c 0,91 -89,163 -188,163H 105", 21, [24, 38, 110, 38, 24, 38, 240, 38, 24, 38, 140, 38, 24, 20000]),
        ("m 283,173c 2,0 165,0 165,0C 544,175 577,238 577,330v 156c 0,94 -48,126 -140,125L 269,609C 167,602 29,702 29,851v 312c 0,111 101,235 242,235h 162c 109,1 144,49 144,136v 162c 0,73 -53,130 -118,130l -353,1", 34, [38, 64, 96, 64, 38, 64, 190, 64, 38, 20000]),
    ]
}
