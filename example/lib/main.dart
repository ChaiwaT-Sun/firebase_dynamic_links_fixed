// Copyright 2018, the Flutter project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_dynamic_links_fixed/firebase_dynamic_links_fixed.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MaterialApp(
    title: 'Dynamic Links Example',
    initialRoute: '/',
    onGenerateRoute: _generateRoute,
  ));
}

Route<dynamic>? _generateRoute(RouteSettings settings) {
  switch (settings.name) {
    case '/':
      return MaterialPageRoute(builder: (_) => const _MainScreen());
    case '/helloworld':
      return MaterialPageRoute(builder: (_) => const _DynamicLinkScreen());
    default:
      return null;
  }
}

class _MainScreen extends StatefulWidget {
  const _MainScreen();

  @override
  State<_MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<_MainScreen> with WidgetsBindingObserver {
  String? _linkMessage;
  bool _isCreatingLink = false;

  static const String _testString =
      'To test: long press link and then copy and click from a non-browser '
      'app. Make sure this is not being tested on iOS simulator and iOS Xcode '
      'is properly set up. See firebase_dynamic_links_fixed/README.md for details.';

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

  Future<void> _createDynamicLink({required bool short}) async {
    setState(() => _isCreatingLink = true);

    try {
      final DynamicLinkParameters parameters = DynamicLinkParameters(
        // Replace with your own Firebase Dynamic Links domain.
        domain: 'cx4k7.app.goo.gl',
        link: Uri.parse('https://dynamic.link.example/helloworld'),
        androidParameters: AndroidParameters(
          packageName: 'io.flutter.plugins.firebasedynamiclinksexample',
          minimumVersion: 0,
        ),
        dynamicLinkParametersOptions: DynamicLinkParametersOptions(
          shortDynamicLinkPathLength: ShortDynamicLinkPathLength.short,
        ),
        iosParameters: IosParameters(
          bundleId: 'com.google.FirebaseCppDynamicLinksTestApp.dev',
          minimumVersion: '0',
        ),
      );

      final Uri url;
      if (short) {
        final ShortDynamicLink shortLink = await parameters.buildShortLink();
        url = shortLink.shortUrl;
      } else {
        url = await parameters.buildUrl();
      }

      setState(() {
        _linkMessage = url.toString();
        _isCreatingLink = false;
      });
    } catch (e) {
      setState(() {
        _linkMessage = 'Error: $e';
        _isCreatingLink = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dynamic Links Example')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                ElevatedButton(
                  onPressed:
                      _isCreatingLink ? null : () => _createDynamicLink(short: false),
                  child: const Text('Get Long Link'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed:
                      _isCreatingLink ? null : () => _createDynamicLink(short: true),
                  child: const Text('Get Short Link'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () async {
                final msg = _linkMessage;
                if (msg != null) {
                  final uri = Uri.parse(msg);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }
                }
              },
              onLongPress: () {
                final msg = _linkMessage;
                if (msg != null) {
                  Clipboard.setData(ClipboardData(text: msg));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied Link!')),
                  );
                }
              },
              child: Text(
                _linkMessage ?? '',
                style: const TextStyle(color: Colors.blue),
              ),
            ),
            if (_linkMessage != null) ...[
              const SizedBox(height: 8),
              const Text(_testString, textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}

class _DynamicLinkScreen extends StatelessWidget {
  const _DynamicLinkScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hello World DeepLink')),
      body: const Center(child: Text('Hello, World!')),
    );
  }
}
