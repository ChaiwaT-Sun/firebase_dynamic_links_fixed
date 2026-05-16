# firebase_dynamic_links_fixed

[![pub package](https://img.shields.io/pub/v/firebase_dynamic_links_fixed.svg)](https://pub.dev/packages/firebase_dynamic_links_fixed)
[![License: BSD](https://img.shields.io/badge/license-BSD-blue.svg)](LICENSE)

A Flutter plugin for [Google Dynamic Links for Firebase](https://firebase.google.com/docs/dynamic-links/) — migrated to support **firebase_core ^4.4.0**, **Flutter 3.x**, **Dart 3**, **null safety**, **AGP 8+**, and **Kotlin 1.9+**.

> ⚠️ **Note:** Firebase Dynamic Links is [deprecated by Google](https://firebase.google.com/support/dynamic-links-faq) and will be shut down on **August 25, 2025**. This package is provided for teams that need to maintain existing integrations until they can migrate to an alternative solution.

---

## Features

- Create long and short Dynamic Link URLs
- Retrieve pending Dynamic Links when the app is opened via a link
- Full support for Android and iOS parameters (analytics, iTunes Connect, navigation, social meta tags)

---

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  firebase_dynamic_links_fixed: ^1.0.0
  firebase_core: ^4.4.0
```

---

## Setup

### 1. Firebase project

Follow the [Firebase setup guide](https://firebase.google.com/docs/flutter/setup) to add Firebase to your Flutter app (download `google-services.json` for Android and `GoogleService-Info.plist` for iOS).

### 2. Initialize Firebase in `main.dart`

```dart
import 'package:firebase_core/firebase_core.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}
```

### 3. Android — Deep link intent filter

Add to your `AndroidManifest.xml` inside `<activity>`:

```xml
<intent-filter android:autoVerify="true">
  <action android:name="android.intent.action.VIEW"/>
  <category android:name="android.intent.category.DEFAULT"/>
  <category android:name="android.intent.category.BROWSABLE"/>
  <data android:scheme="https" android:host="YOUR_SUBDOMAIN.page.link"/>
</intent-filter>
```

### 4. iOS — URL scheme and Associated Domains

In Xcode:

1. **Info** tab → add a URL Type with your bundle ID as the URL Scheme.
2. **Signing & Capabilities** tab → enable **Associated Domains** and add:

```
applinks:YOUR_SUBDOMAIN.page.link
```

---

## Usage

### Import

```dart
import 'package:firebase_dynamic_links_fixed/firebase_dynamic_links.dart';
```

### Create a long Dynamic Link

```dart
final DynamicLinkParameters parameters = DynamicLinkParameters(
  domain: 'YOUR_SUBDOMAIN.page.link',
  link: Uri.parse('https://example.com/'),
  androidParameters: AndroidParameters(
    packageName: 'com.example.android',
    minimumVersion: 125,
  ),
  iosParameters: IosParameters(
    bundleId: 'com.example.ios',
    minimumVersion: '1.0.1',
    appStoreId: '123456789',
  ),
  googleAnalyticsParameters: GoogleAnalyticsParameters(
    campaign: 'example-promo',
    medium: 'social',
    source: 'twitter',
  ),
  socialMetaTagParameters: SocialMetaTagParameters(
    title: 'Example Dynamic Link',
    description: 'This link works whether the app is installed or not!',
  ),
);

final Uri longUrl = await parameters.buildUrl();
```

### Create a short Dynamic Link

```dart
final ShortDynamicLink shortLink = await parameters.buildShortLink();
final Uri shortUrl = shortLink.shortUrl;
```

### Shorten an existing long URL

```dart
final ShortDynamicLink shortened = await DynamicLinkParameters.shortenUrl(
  Uri.parse('https://YOUR_SUBDOMAIN.page.link/?link=https://example.com/&apn=com.example.android'),
  DynamicLinkParametersOptions(
    shortDynamicLinkPathLength: ShortDynamicLinkPathLength.unguessable,
  ),
);
final Uri shortUrl = shortened.shortUrl;
```

### Handle incoming Dynamic Links

Call `retrieveDynamicLink()` on app start and when the app resumes:

```dart
class _HomeState extends State<Home> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _retrieveDynamicLink();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _retrieveDynamicLink();
    }
  }

  Future<void> _retrieveDynamicLink() async {
    final PendingDynamicLinkData? data =
        await FirebaseDynamicLinks.instance.retrieveDynamicLink();
    final Uri? deepLink = data?.link;

    if (deepLink != null && mounted) {
      Navigator.pushNamed(context, deepLink.path);
    }
  }
}
```

---

## API Reference

| Class | Description |
|---|---|
| `FirebaseDynamicLinks` | Singleton entry point. Call `instance.retrieveDynamicLink()`. |
| `DynamicLinkParameters` | Builder for long/short links. |
| `AndroidParameters` | Android-specific link parameters. |
| `IosParameters` | iOS-specific link parameters. |
| `GoogleAnalyticsParameters` | UTM analytics parameters. |
| `ItunesConnectAnalyticsParameters` | iTunes Connect analytics parameters. |
| `NavigationInfoParameters` | Force-redirect behaviour. |
| `SocialMetaTagParameters` | OG title/description/image for social sharing. |
| `DynamicLinkParametersOptions` | Short link path length (`unguessable` or `short`). |
| `PendingDynamicLinkData` | Data returned from `retrieveDynamicLink()`. |
| `ShortDynamicLink` | Result of `buildShortLink()` / `shortenUrl()`. |

---

## Requirements

| | Minimum |
|---|---|
| Dart SDK | 3.0.0 |
| Flutter | 3.10.0 |
| Android `minSdk` | 21 |
| Android `compileSdk` | 34 |
| iOS deployment target | 12.0 |
| Kotlin | 1.9+ |
| AGP | 8.1+ |
| `firebase_core` | ^4.4.0 |

---

## License

BSD — see [LICENSE](LICENSE).
