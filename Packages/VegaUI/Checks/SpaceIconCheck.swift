// Licensed under GPL-3.0. See LICENSE.
// VegaDesign is built as a module beside the binary, then linked in:
//
//   D=Packages/VegaDesign/Sources/VegaDesign; mkdir -p /tmp/x-lib
//   swiftc -swift-version 5 -parse-as-library -emit-module -emit-library -module-name VegaDesign \
//          -module-link-name VegaDesign $D/*.swift -emit-module-path /tmp/x-lib/VegaDesign.swiftmodule \
//          -o /tmp/x-lib/libVegaDesign.dylib && \
//   swiftc -swift-version 5 -I /tmp/x-lib -L /tmp/x-lib -lVegaDesign -Xlinker -rpath -Xlinker /tmp/x-lib \
//          Packages/VegaUI/Sources/VegaUI/Spaces/SpaceIconPicker.swift Packages/VegaUI/Checks/SpaceIconCheck.swift -o /tmp/x && /tmp/x
@main
struct SpaceIconCheck {
    static func main() {
        for placeholder in ["", "square.grid.2x2", "house", "person.fill"] {
            precondition(SpaceIcon.isDot(placeholder), placeholder)
        }
        precondition(!SpaceIcon.isDot("star"))
        precondition(!SpaceIcon.isDot("🚀"))
        precondition(!SpaceIcon.isDot("vega.agent:0F0F0F0F-0000-0000-0000-000000000000"))
        precondition(SpaceIcon.isEmoji("🚀") && !SpaceIcon.isEmoji("star"))
        print("ok")
    }
}
