// swift-tools-version:5.3

import PackageDescription

let package = Package(
  name: "MSAL",
  platforms: [
        .macOS(.v10_13),.iOS(.v14)
  ],
  products: [
      .library(
          name: "MSAL",
          targets: ["MSAL"]),
  ],
  targets: [
//      .binaryTarget(name: "MSAL", url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc/releases/download/1.2.9/MSAL.zip", checksum: "5fe144133a3094d2bf5c8932641c3a2935412f41059e52d6b7e3361c617ec59a"),
      .binaryTarget(name: "MSAL", url: "https://github.com/dsay/microsoft-authentication-library-for-objc/releases/download/1.2.9-heylo/MSAL.zip", checksum: "1f3af396f430120aac914ed9ebb0f6509c72a4768d3607ffe44ec52574434f71")
  ]
)

