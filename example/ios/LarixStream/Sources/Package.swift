// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LarixStream",
    platforms: [.iOS(.v12)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "LarixLib",
            type: .static,
            targets: ["LarixSupport", "LarixUI", "LarixCore", "LarixStream"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
    .binaryTarget(name: "mbl", path: "lib/mbl.xcframework"),
    .target(name: "LarixCore",
            dependencies: ["mbl"],
           path: "Sources/mblBridge"),
    .target(name: "LarixObjC",
            dependencies: [],
           path: "Sources/LarixObjC"),
    .target(name: "LarixSupport",
            dependencies: ["LarixObjC"]),
    .target(name: "LarixUI",
            dependencies: ["LarixObjC", "LarixSupport"]),
    .target(
        name: "LarixStream",
        dependencies: ["mbl", "LarixCore", "LarixUI"],
        resources: [
          .process("Metal/StreamShaders.metal")
        ] )
    ]
)
