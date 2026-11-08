// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.
//
// Generated file. Do not edit.
//

import PackageDescription

let package = Package(
    name: "FlutterGeneratedPluginSwiftPackage",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(name: "FlutterGeneratedPluginSwiftPackage", type: .static, targets: ["FlutterGeneratedPluginSwiftPackage"])
    ],
    dependencies: [
        .package(name: "app_links", path: "../.packages/app_links-7.2.2"),
        .package(name: "connectivity_plus", path: "../.packages/connectivity_plus-7.3.2"),
        .package(name: "firebase_core", path: "../.packages/firebase_core-5.1.0"),
        .package(name: "firebase_crashlytics", path: "../.packages/firebase_crashlytics-6.0.1"),
        .package(name: "firebase_messaging", path: "../.packages/firebase_messaging-17.0.1"),
        .package(name: "flutter_image_compress_common", path: "../.packages/flutter_image_compress_common-1.1.1"),
        .package(name: "flutter_local_notifications", path: "../.packages/flutter_local_notifications-22.3.3"),
        .package(name: "google_mobile_ads", path: "../.packages/google_mobile_ads-9.2.0"),
        .package(name: "google_sign_in_ios", path: "../.packages/google_sign_in_ios-6.4.0"),
        .package(name: "image_cropper", path: "../.packages/image_cropper-13.0.0"),
        .package(name: "image_picker_ios", path: "../.packages/image_picker_ios-0.8.13+15"),
        .package(name: "integration_test", path: "../.packages/integration_test"),
        .package(name: "share_plus", path: "../.packages/share_plus-13.3.1"),
        .package(name: "shared_preferences_foundation", path: "../.packages/shared_preferences_foundation-2.6.1"),
        .package(name: "sqflite_darwin", path: "../.packages/sqflite_darwin-2.4.5"),
        .package(name: "url_launcher_ios", path: "../.packages/url_launcher_ios-6.4.2"),
        .package(name: "webview_flutter_wkwebview", path: "../.packages/webview_flutter_wkwebview-3.27.2"),
        .package(name: "FlutterFramework", path: "../.packages/FlutterFramework")
    ],
    targets: [
        .target(
            name: "FlutterGeneratedPluginSwiftPackage",
            dependencies: [
                .product(name: "app-links", package: "app_links"),
                .product(name: "connectivity-plus", package: "connectivity_plus"),
                .product(name: "firebase-core", package: "firebase_core"),
                .product(name: "firebase-crashlytics", package: "firebase_crashlytics"),
                .product(name: "firebase-messaging", package: "firebase_messaging"),
                .product(name: "flutter-image-compress-common", package: "flutter_image_compress_common"),
                .product(name: "flutter-local-notifications", package: "flutter_local_notifications"),
                .product(name: "google-mobile-ads", package: "google_mobile_ads"),
                .product(name: "google-sign-in-ios", package: "google_sign_in_ios"),
                .product(name: "image-cropper", package: "image_cropper"),
                .product(name: "image-picker-ios", package: "image_picker_ios"),
                .product(name: "integration-test", package: "integration_test"),
                .product(name: "share-plus", package: "share_plus"),
                .product(name: "shared-preferences-foundation", package: "shared_preferences_foundation"),
                .product(name: "sqflite-darwin", package: "sqflite_darwin"),
                .product(name: "url-launcher-ios", package: "url_launcher_ios"),
                .product(name: "webview-flutter-wkwebview", package: "webview_flutter_wkwebview"),
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ]
        )
    ]
)
