// swift-tools-version:5.1
import PackageDescription

let auxilliaryFiles = ["README.md", "LICENSE"]
let package = Package(
  name: "LoftDataStructures_UnsafeMutableProjection",
  products: [
    .library(
      name: "LoftDataStructures_UnsafeMutableProjection",
      targets: ["LoftDataStructures_UnsafeMutableProjection"]),
  ],
  targets: [
    .target(
      name: "LoftDataStructures_UnsafeMutableProjection",
      path: ".",
      exclude: auxilliaryFiles + ["Tests.swift"],
      sources: ["UnsafeMutableProjection.swift"]),
    .testTarget(
      name: "Test",
      dependencies: ["LoftDataStructures_UnsafeMutableProjection"],
      path: ".",
      exclude: auxilliaryFiles + ["UnsafeMutableProjection.swift"],
      sources: ["Tests.swift"]
    ),
  ]
)
