// swift-tools-version:4.2
// aws 52.58.72.19
// aws iln2 18.197.144.50
// vpc bei amazon 172.31.0.0/16
// docker run --name postgres -e POSTGRES_DB=ilndb -e POSTGRES_USER=ilnuser -e POSTGRES_PASSWORD=iln -p 5432:5432 -d postgres

// ssh -i "iln2.pem" ubuntu@ec2-18-197-144-50.eu-central-1.compute.amazonaws.com

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
