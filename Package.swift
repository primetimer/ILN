// swift-tools-version:4.1

// docker run --name postgres -e POSTGRES_DB=ilndb -e POSTGRES_USER=ilnuser -e POSTGRES_PASSWORD=iln -p 5432:5432 -d postgres
import PackageDescription

let package = Package(
  name: "ILNApp",
  dependencies: [
    .package(url: "https://github.com/vapor/vapor.git", from: "3.0.0"),
    .package(url: "https://github.com/vapor/fluent-postgresql.git", from: "1.0.0"),
    .package(url: "https://github.com/vapor/leaf.git", from: "3.0.0"),
    .package(url: "https://github.com/vapor/auth.git", from: "2.0.0")
  ],
  targets: [
    .target(name: "App", dependencies: ["FluentPostgreSQL", "Vapor", "Leaf","Authentication"]),
    .target(name: "Run", dependencies: ["App"]),
    .testTarget(name: "AppTests", dependencies: ["App"])
  ]
)
