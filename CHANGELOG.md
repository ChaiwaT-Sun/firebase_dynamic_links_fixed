## 1.0.0

* **Breaking** Renamed package to `firebase_dynamic_links_fixed`.
* Migrated to null safety (Dart 3 / `sdk: ">=3.0.0 <4.0.0"`).
* Updated `firebase_core` dependency to `^4.4.0`.
* Requires Flutter `>=3.10.0`.
* **Android** – Rewrote plugin in Kotlin; replaced deprecated `Registrar` API with
  `FlutterPlugin` + `ActivityAware` (Flutter embedding v2).
* **Android** – Added `namespace` to `build.gradle` (required by AGP 8+).
* **Android** – Upgraded AGP to `8.1.0`, Gradle wrapper to `8.3`, Kotlin to `1.9.10`,
  `compileSdk`/`targetSdk` to `34`, `minSdk` to `21`, Java/Kotlin target to 17.
* **Android** – Updated `firebase-dynamic-links` to `21.2.0`.
* **Android** – Removed `jcenter()` in favour of `mavenCentral()`.
* **Android** – Example `MainActivity` migrated from Java `FlutterActivity` +
  `GeneratedPluginRegistrant` to Kotlin `FlutterActivity` (embedding v2).
* **iOS** – Updated podspec: renamed to `firebase_dynamic_links_fixed`, bumped
  `Firebase/DynamicLinks` to `~> 10.0`, deployment target to `12.0`.
* **iOS** – Updated `FIRDynamicLinkComponents` initialiser to use `domainURIPrefix:`
  (replaces deprecated `domain:` parameter in Firebase iOS SDK 10+).
* **Dart** – Replaced `@required` annotations with Dart-native `required` keyword.
* **Dart** – All nullable types now use `?` syntax; removed `assert(x != null)` guards.
* **Dart** – Updated mock-channel setup in tests to use
  `TestDefaultBinaryMessengerBinding` (replaces deprecated `setMockMethodCallHandler`
  on the channel directly).
* **Example** – Replaced deprecated `RaisedButton` with `ElevatedButton`,
  `launch()` with `launchUrl()`, and added `Firebase.initializeApp()` in `main()`.
* **Example** – Added `android:exported="true"` and Flutter embedding v2 metadata
  to `AndroidManifest.xml`.

## 0.1.1

* Update example to create a clickable and copyable link.

## 0.1.0+2

* Change android `invites` dependency to `dynamic links` dependency.

## 0.1.0+1

* Bump Android dependencies to latest.

## 0.1.0

* **Breaking Change** Calls to retrieve dynamic links on iOS always returns null after first call.

## 0.0.6

* Bump Android and Firebase dependency versions.

## 0.0.5

* Added capability to receive dynamic links.

## 0.0.4

* Fixed dynamic link dartdoc generation.

## 0.0.3

* Fixed incorrect homepage link in pubspec.

## 0.0.2

* Updated Gradle tooling to match Android Studio 3.1.2.

## 0.0.1

* Initial release with api to create long or short dynamic links.
