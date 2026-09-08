// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KotranaNativeLogic",
    products: [.library(name: "KotranaNativeLogic", targets: ["KotranaNativeLogic"])],
    targets: [
        .target(name: "KotranaNativeLogic", path: "Shared", exclude: ["StrengthLiveActivityAttributes.swift"]),
        .target(name: "WatchModels", path: "StrengthAppWatch Watch App/Models"),
        .testTarget(name: "KotranaNativeLogicTests", dependencies: ["KotranaNativeLogic", "WatchModels"], path: "NativeLogicTests"),
    ]
)
