// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PlanReview",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "PlanReview", targets: ["PlanReview"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-markdown.git", from: "0.4.0"),
        .package(url: "https://github.com/JohnSundell/Ink.git", from: "0.6.0")
    ],
    targets: [
        .executableTarget(
            name: "PlanReview",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown"),
                .product(name: "Ink", package: "Ink")
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "PlanReviewTests",
            dependencies: [
                "PlanReview",
                .product(name: "Markdown", package: "swift-markdown")
            ],
            path: "Tests"
        )
    ]
)
