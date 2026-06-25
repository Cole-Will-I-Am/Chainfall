// swift-tools-version:5.9
//
// LOCAL / CI ENGINE VERIFICATION ONLY — not part of the iOS app build (XcodeGen builds
// that from project.yml). Compiles the pure engine in Chainfall/Sources/Engine as the
// `ChainfallCore` module so the grid/cascade/heat/bank logic can be unit-tested with
// `swift test` on any machine. The same files are compiled into the iOS `Chainfall`
// target.
import PackageDescription

let package = Package(
    name: "ChainfallCore",
    products: [.library(name: "ChainfallCore", targets: ["ChainfallCore"])],
    targets: [
        .target(name: "ChainfallCore", path: "Chainfall/Sources/Engine"),
        .testTarget(name: "ChainfallCoreTests", dependencies: ["ChainfallCore"], path: "CoreTests"),
    ]
)
