// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "FirebaseDynamicLinksPlugin.h"
@import Firebase;

// ---------------------------------------------------------------------------
// NSError → FlutterError convenience
// ---------------------------------------------------------------------------
@interface NSError (FlutterError)
@property(readonly, nonatomic) FlutterError *flutterError;
@end

@implementation NSError (FlutterError)
- (FlutterError *)flutterError {
  return [FlutterError errorWithCode:[NSString stringWithFormat:@"Error %d", (int)self.code]
                             message:self.domain
                             details:self.localizedDescription];
}
@end

// ---------------------------------------------------------------------------
// Plugin implementation
// ---------------------------------------------------------------------------
@interface FLTFirebaseDynamicLinksPlugin ()
@property(nonatomic, strong) FIRDynamicLink *dynamicLink;
@end

@implementation FLTFirebaseDynamicLinksPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  FlutterMethodChannel *channel =
      [FlutterMethodChannel methodChannelWithName:@"plugins.flutter.io/firebase_dynamic_links"
                                  binaryMessenger:[registrar messenger]];
  FLTFirebaseDynamicLinksPlugin *instance = [[FLTFirebaseDynamicLinksPlugin alloc] init];
  [registrar addMethodCallDelegate:instance channel:channel];
  [registrar addApplicationDelegate:instance];
}

- (instancetype)init {
  self = [super init];
  if (self) {
    // Configure Firebase only if it hasn't been configured yet.
    if (![FIRApp defaultApp]) {
      [FIRApp configure];
    }
  }
  return self;
}

// ---------------------------------------------------------------------------
// Method dispatch
// ---------------------------------------------------------------------------
- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
  if ([@"DynamicLinkParameters#buildUrl" isEqualToString:call.method]) {
    FIRDynamicLinkComponents *components = [self setupParameters:call.arguments];
    result([components.url absoluteString]);

  } else if ([@"DynamicLinkParameters#buildShortLink" isEqualToString:call.method]) {
    FIRDynamicLinkComponents *components = [self setupParameters:call.arguments];
    [components shortenWithCompletion:[self createShortLinkCompletion:result]];

  } else if ([@"DynamicLinkParameters#shortenUrl" isEqualToString:call.method]) {
    FIRDynamicLinkComponentsOptions *options = [self setupOptions:call.arguments];
    NSURL *url = [NSURL URLWithString:call.arguments[@"url"]];
    [FIRDynamicLinkComponents shortenURL:url
                                 options:options
                              completion:[self createShortLinkCompletion:result]];

  } else if ([@"FirebaseDynamicLinks#retrieveDynamicLink" isEqualToString:call.method]) {
    result([self retrieveDynamicLink]);

  } else {
    result(FlutterMethodNotImplemented);
  }
}

// ---------------------------------------------------------------------------
// Retrieve stored dynamic link
// ---------------------------------------------------------------------------
- (NSMutableDictionary *)retrieveDynamicLink {
  if (_dynamicLink != nil) {
    NSMutableDictionary *dynamicLink = [[NSMutableDictionary alloc] init];
    dynamicLink[@"link"] = _dynamicLink.url.absoluteString;

    NSMutableDictionary *iosData = [[NSMutableDictionary alloc] init];
    if (_dynamicLink.minimumAppVersion) {
      iosData[@"minimumVersion"] = _dynamicLink.minimumAppVersion;
    }
    _dynamicLink = nil;
    dynamicLink[@"ios"] = iosData;
    return dynamicLink;
  }
  return nil;
}

// ---------------------------------------------------------------------------
// UIApplicationDelegate hooks
// ---------------------------------------------------------------------------
- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
            options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options {
  return [self checkForDynamicLink:url];
}

- (BOOL)application:(UIApplication *)application
              openURL:(NSURL *)url
    sourceApplication:(NSString *)sourceApplication
           annotation:(id)annotation {
  return [self checkForDynamicLink:url];
}

- (BOOL)checkForDynamicLink:(NSURL *)url {
  FIRDynamicLink *dynamicLink =
      [[FIRDynamicLinks dynamicLinks] dynamicLinkFromCustomSchemeURL:url];
  if (dynamicLink) {
    if (dynamicLink.url) _dynamicLink = dynamicLink;
    return YES;
  }
  return NO;
}

- (BOOL)application:(UIApplication *)application
    continueUserActivity:(NSUserActivity *)userActivity
      restorationHandler:(void (^)(NSArray *))restorationHandler {
  BOOL handled = [[FIRDynamicLinks dynamicLinks]
      handleUniversalLink:userActivity.webpageURL
               completion:^(FIRDynamicLink *_Nullable dynamicLink,
                            NSError *_Nullable error) {
                 self.dynamicLink = dynamicLink;
               }];
  return handled;
}

// ---------------------------------------------------------------------------
// Short-link completion block
// ---------------------------------------------------------------------------
- (FIRDynamicLinkShortenerCompletion)createShortLinkCompletion:(FlutterResult)result {
  return ^(NSURL *_Nullable shortURL,
           NSArray *_Nullable warnings,
           NSError *_Nullable error) {
    if (error) {
      result([error flutterError]);
    } else {
      result(@{
        @"url" : [shortURL absoluteString],
        @"warnings" : warnings ?: @[]
      });
    }
  };
}

// ---------------------------------------------------------------------------
// Options helper
// ---------------------------------------------------------------------------
- (FIRDynamicLinkComponentsOptions *)setupOptions:(NSDictionary *)arguments {
  id optionsArg = arguments[@"dynamicLinkParametersOptions"];
  if (!optionsArg || [optionsArg isEqual:[NSNull null]]) return nil;

  NSDictionary *params = (NSDictionary *)optionsArg;
  FIRDynamicLinkComponentsOptions *options = [FIRDynamicLinkComponentsOptions options];

  id pathLengthArg = params[@"shortDynamicLinkPathLength"];
  if (pathLengthArg && ![pathLengthArg isEqual:[NSNull null]]) {
    switch ([pathLengthArg intValue]) {
      case 0:
        options.pathLength = FIRShortDynamicLinkPathLengthUnguessable;
        break;
      case 1:
        options.pathLength = FIRShortDynamicLinkPathLengthShort;
        break;
      default:
        break;
    }
  }
  return options;
}

// ---------------------------------------------------------------------------
// Parameters builder
// Firebase SDK 10+ uses domainURIPrefix (full URL) instead of plain domain.
// We accept the old "domain" key and convert it to a full https:// prefix.
// ---------------------------------------------------------------------------
- (FIRDynamicLinkComponents *)setupParameters:(NSDictionary *)arguments {
  NSURL *link = [NSURL URLWithString:arguments[@"link"]];

  // Support both legacy short domain (e.g. "abc.page.link") and full prefix.
  NSString *domain = arguments[@"domain"];
  NSString *domainURIPrefix = domain;
  if (![domain hasPrefix:@"https://"] && ![domain hasPrefix:@"http://"]) {
    domainURIPrefix = [NSString stringWithFormat:@"https://%@", domain];
  }

  FIRDynamicLinkComponents *components =
      [FIRDynamicLinkComponents componentsWithLink:link
                                  domainURIPrefix:domainURIPrefix];

  // Android parameters
  id androidArg = arguments[@"androidParameters"];
  if (androidArg && ![androidArg isEqual:[NSNull null]]) {
    NSDictionary *params = (NSDictionary *)androidArg;
    FIRDynamicLinkAndroidParameters *androidParams =
        [FIRDynamicLinkAndroidParameters parametersWithPackageName:params[@"packageName"]];

    id fallbackUrl = params[@"fallbackUrl"];
    id minimumVersion = params[@"minimumVersion"];

    if (fallbackUrl && ![fallbackUrl isEqual:[NSNull null]])
      androidParams.fallbackURL = [NSURL URLWithString:fallbackUrl];
    if (minimumVersion && ![minimumVersion isEqual:[NSNull null]])
      androidParams.minimumVersion = [minimumVersion integerValue];

    components.androidParameters = androidParams;
  }

  // Options
  id optionsArg = arguments[@"dynamicLinkParametersOptions"];
  if (optionsArg && ![optionsArg isEqual:[NSNull null]]) {
    components.options = [self setupOptions:arguments];
  }

  // Google Analytics parameters
  id gaArg = arguments[@"googleAnalyticsParameters"];
  if (gaArg && ![gaArg isEqual:[NSNull null]]) {
    NSDictionary *params = (NSDictionary *)gaArg;
    FIRDynamicLinkGoogleAnalyticsParameters *gaParams =
        [FIRDynamicLinkGoogleAnalyticsParameters parameters];

    id campaign = params[@"campaign"];
    id content  = params[@"content"];
    id medium   = params[@"medium"];
    id source   = params[@"source"];
    id term     = params[@"term"];

    if (campaign && ![campaign isEqual:[NSNull null]]) gaParams.campaign = campaign;
    if (content  && ![content  isEqual:[NSNull null]]) gaParams.content  = content;
    if (medium   && ![medium   isEqual:[NSNull null]]) gaParams.medium   = medium;
    if (source   && ![source   isEqual:[NSNull null]]) gaParams.source   = source;
    if (term     && ![term     isEqual:[NSNull null]]) gaParams.term     = term;

    components.analyticsParameters = gaParams;
  }

  // iOS parameters
  id iosArg = arguments[@"iosParameters"];
  if (iosArg && ![iosArg isEqual:[NSNull null]]) {
    NSDictionary *params = (NSDictionary *)iosArg;
    FIRDynamicLinkIOSParameters *iosParams =
        [FIRDynamicLinkIOSParameters parametersWithBundleID:params[@"bundleId"]];

    id appStoreID        = params[@"appStoreId"];
    id customScheme      = params[@"customScheme"];
    id fallbackURL       = params[@"fallbackUrl"];
    id iPadBundleID      = params[@"ipadBundleId"];
    id iPadFallbackURL   = params[@"ipadFallbackUrl"];
    id minimumAppVersion = params[@"minimumVersion"];

    if (appStoreID        && ![appStoreID        isEqual:[NSNull null]])
      iosParams.appStoreID = appStoreID;
    if (customScheme      && ![customScheme      isEqual:[NSNull null]])
      iosParams.customScheme = customScheme;
    if (fallbackURL       && ![fallbackURL       isEqual:[NSNull null]])
      iosParams.fallbackURL = [NSURL URLWithString:fallbackURL];
    if (iPadBundleID      && ![iPadBundleID      isEqual:[NSNull null]])
      iosParams.iPadBundleID = iPadBundleID;
    if (iPadFallbackURL   && ![iPadFallbackURL   isEqual:[NSNull null]])
      iosParams.iPadFallbackURL = [NSURL URLWithString:iPadFallbackURL];
    if (minimumAppVersion && ![minimumAppVersion isEqual:[NSNull null]])
      iosParams.minimumAppVersion = minimumAppVersion;

    components.iOSParameters = iosParams;
  }

  // iTunes Connect parameters
  id itunesArg = arguments[@"itunesConnectAnalyticsParameters"];
  if (itunesArg && ![itunesArg isEqual:[NSNull null]]) {
    NSDictionary *params = (NSDictionary *)itunesArg;
    FIRDynamicLinkItunesConnectAnalyticsParameters *itunesParams =
        [FIRDynamicLinkItunesConnectAnalyticsParameters parameters];

    id affiliateToken = params[@"affiliateToken"];
    id campaignToken  = params[@"campaignToken"];
    id providerToken  = params[@"providerToken"];

    if (affiliateToken && ![affiliateToken isEqual:[NSNull null]])
      itunesParams.affiliateToken = affiliateToken;
    if (campaignToken  && ![campaignToken  isEqual:[NSNull null]])
      itunesParams.campaignToken = campaignToken;
    if (providerToken  && ![providerToken  isEqual:[NSNull null]])
      itunesParams.providerToken = providerToken;

    components.iTunesConnectParameters = itunesParams;
  }

  // Navigation info parameters
  id navArg = arguments[@"navigationInfoParameters"];
  if (navArg && ![navArg isEqual:[NSNull null]]) {
    NSDictionary *params = (NSDictionary *)navArg;
    FIRDynamicLinkNavigationInfoParameters *navParams =
        [FIRDynamicLinkNavigationInfoParameters parameters];

    id forcedRedirect = params[@"forcedRedirectEnabled"];
    if (forcedRedirect && ![forcedRedirect isEqual:[NSNull null]])
      navParams.forcedRedirectEnabled = [forcedRedirect boolValue];

    components.navigationInfoParameters = navParams;
  }

  // Social meta tag parameters
  id socialArg = arguments[@"socialMetaTagParameters"];
  if (socialArg && ![socialArg isEqual:[NSNull null]]) {
    NSDictionary *params = (NSDictionary *)socialArg;
    FIRDynamicLinkSocialMetaTagParameters *socialParams =
        [FIRDynamicLinkSocialMetaTagParameters parameters];

    id descriptionText = params[@"description"];
    id imageURL        = params[@"imageUrl"];
    id title           = params[@"title"];

    if (descriptionText && ![descriptionText isEqual:[NSNull null]])
      socialParams.descriptionText = descriptionText;
    if (imageURL        && ![imageURL        isEqual:[NSNull null]])
      socialParams.imageURL = [NSURL URLWithString:imageURL];
    if (title           && ![title           isEqual:[NSNull null]])
      socialParams.title = title;

    components.socialMetaTagParameters = socialParams;
  }

  return components;
}

@end
