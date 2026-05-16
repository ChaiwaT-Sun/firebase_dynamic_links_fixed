// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package io.flutter.plugins.firebasedynamiclinks

import android.app.Activity
import android.net.Uri
import com.google.firebase.dynamiclinks.DynamicLink
import com.google.firebase.dynamiclinks.FirebaseDynamicLinks
import com.google.firebase.dynamiclinks.ShortDynamicLink
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/** FirebaseDynamicLinksPlugin */
class FirebaseDynamicLinksPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {

    private lateinit var channel: MethodChannel
    private var activity: Activity? = null

    // ── FlutterPlugin ────────────────────────────────────────────────────────

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(
            binding.binaryMessenger,
            "plugins.flutter.io/firebase_dynamic_links"
        )
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    // ── ActivityAware ────────────────────────────────────────────────────────

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    // ── MethodCallHandler ────────────────────────────────────────────────────

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "DynamicLinkParameters#buildUrl" -> {
                val builder = setupParameters(call)
                result.success(builder.buildDynamicLink().uri.toString())
            }
            "DynamicLinkParameters#buildShortLink" -> {
                val builder = setupParameters(call)
                buildShortDynamicLink(builder, call, createShortLinkListener(result))
            }
            "DynamicLinkParameters#shortenUrl" -> {
                val builder = FirebaseDynamicLinks.getInstance().createDynamicLink()
                val url = Uri.parse(call.argument<String>("url"))
                builder.setLongLink(url)
                buildShortDynamicLink(builder, call, createShortLinkListener(result))
            }
            "FirebaseDynamicLinks#retrieveDynamicLink" -> {
                handleRetrieveDynamicLink(result)
            }
            else -> result.notImplemented()
        }
    }

    // ── Private helpers ──────────────────────────────────────────────────────

    private fun handleRetrieveDynamicLink(result: Result) {
        val currentActivity = activity
        if (currentActivity == null) {
            result.error("no_activity", "Plugin is not attached to an activity.", null)
            return
        }

        FirebaseDynamicLinks.getInstance()
            .getDynamicLink(currentActivity.intent)
            .addOnCompleteListener(currentActivity) { task ->
                if (task.isSuccessful) {
                    val data = task.result
                    if (data != null) {
                        val dynamicLink = mutableMapOf<String, Any>()
                        dynamicLink["link"] = data.link.toString()

                        val androidData = mutableMapOf<String, Any>()
                        androidData["clickTimestamp"] = data.clickTimestamp
                        androidData["minimumVersion"] = data.minimumAppVersion

                        dynamicLink["android"] = androidData
                        result.success(dynamicLink)
                        return@addOnCompleteListener
                    }
                }
                result.success(null)
            }
    }

    private fun createShortLinkListener(result: Result) =
        com.google.android.gms.tasks.OnCompleteListener<ShortDynamicLink> { task ->
            if (task.isSuccessful) {
                val url = mutableMapOf<String, Any>()
                url["url"] = task.result.shortLink.toString()

                val warnings = task.result.warnings.map { it.message ?: "" }
                url["warnings"] = warnings

                result.success(url)
            } else {
                val exception = task.exception
                val errMsg = exception?.localizedMessage ?: "Unable to create short link"
                result.error("short_link_error", errMsg, null)
            }
        }

    private fun buildShortDynamicLink(
        builder: DynamicLink.Builder,
        call: MethodCall,
        listener: com.google.android.gms.tasks.OnCompleteListener<ShortDynamicLink>
    ) {
        var suffix: Int? = null

        val options = call.argument<Map<String, Any>>("dynamicLinkParametersOptions")
        if (options != null) {
            val pathLength = options["shortDynamicLinkPathLength"] as? Int
            suffix = when (pathLength) {
                0 -> ShortDynamicLink.Suffix.UNGUESSABLE
                1 -> ShortDynamicLink.Suffix.SHORT
                else -> null
            }
        }

        if (suffix != null) {
            builder.buildShortDynamicLink(suffix).addOnCompleteListener(listener)
        } else {
            builder.buildShortDynamicLink().addOnCompleteListener(listener)
        }
    }

    private fun setupParameters(call: MethodCall): DynamicLink.Builder {
        val dynamicLinkBuilder = FirebaseDynamicLinks.getInstance().createDynamicLink()

        val domain: String = call.argument("domain")!!
        val link: String = call.argument("link")!!

        dynamicLinkBuilder.setDynamicLinkDomain(domain)
        dynamicLinkBuilder.setLink(Uri.parse(link))

        val androidParameters = call.argument<Map<String, Any>>("androidParameters")
        if (androidParameters != null) {
            val packageName = androidParameters["packageName"] as String
            val fallbackUrl = androidParameters["fallbackUrl"] as? String
            val minimumVersion = androidParameters["minimumVersion"] as? Int

            val androidBuilder = DynamicLink.AndroidParameters.Builder(packageName)
            fallbackUrl?.let { androidBuilder.setFallbackUrl(Uri.parse(it)) }
            minimumVersion?.let { androidBuilder.setMinimumVersion(it) }

            dynamicLinkBuilder.setAndroidParameters(androidBuilder.build())
        }

        val googleAnalyticsParameters =
            call.argument<Map<String, Any>>("googleAnalyticsParameters")
        if (googleAnalyticsParameters != null) {
            val gaBuilder = DynamicLink.GoogleAnalyticsParameters.Builder()
            (googleAnalyticsParameters["campaign"] as? String)?.let { gaBuilder.setCampaign(it) }
            (googleAnalyticsParameters["content"] as? String)?.let { gaBuilder.setContent(it) }
            (googleAnalyticsParameters["medium"] as? String)?.let { gaBuilder.setMedium(it) }
            (googleAnalyticsParameters["source"] as? String)?.let { gaBuilder.setSource(it) }
            (googleAnalyticsParameters["term"] as? String)?.let { gaBuilder.setTerm(it) }
            dynamicLinkBuilder.setGoogleAnalyticsParameters(gaBuilder.build())
        }

        val iosParameters = call.argument<Map<String, Any>>("iosParameters")
        if (iosParameters != null) {
            val bundleId = iosParameters["bundleId"] as String
            val iosBuilder = DynamicLink.IosParameters.Builder(bundleId)
            (iosParameters["appStoreId"] as? String)?.let { iosBuilder.setAppStoreId(it) }
            (iosParameters["customScheme"] as? String)?.let { iosBuilder.setCustomScheme(it) }
            (iosParameters["fallbackUrl"] as? String)?.let {
                iosBuilder.setFallbackUrl(Uri.parse(it))
            }
            (iosParameters["ipadBundleId"] as? String)?.let { iosBuilder.setIpadBundleId(it) }
            (iosParameters["ipadFallbackUrl"] as? String)?.let {
                iosBuilder.setIpadFallbackUrl(Uri.parse(it))
            }
            (iosParameters["minimumVersion"] as? String)?.let { iosBuilder.setMinimumVersion(it) }
            dynamicLinkBuilder.setIosParameters(iosBuilder.build())
        }

        val itunesParameters =
            call.argument<Map<String, Any>>("itunesConnectAnalyticsParameters")
        if (itunesParameters != null) {
            val itunesBuilder = DynamicLink.ItunesConnectAnalyticsParameters.Builder()
            (itunesParameters["affiliateToken"] as? String)?.let {
                itunesBuilder.setAffiliateToken(it)
            }
            (itunesParameters["campaignToken"] as? String)?.let {
                itunesBuilder.setCampaignToken(it)
            }
            (itunesParameters["providerToken"] as? String)?.let {
                itunesBuilder.setProviderToken(it)
            }
            dynamicLinkBuilder.setItunesConnectAnalyticsParameters(itunesBuilder.build())
        }

        val navigationParameters = call.argument<Map<String, Any>>("navigationInfoParameters")
        if (navigationParameters != null) {
            val navBuilder = DynamicLink.NavigationInfoParameters.Builder()
            (navigationParameters["forcedRedirectEnabled"] as? Boolean)?.let {
                navBuilder.setForcedRedirectEnabled(it)
            }
            dynamicLinkBuilder.setNavigationInfoParameters(navBuilder.build())
        }

        val socialParameters = call.argument<Map<String, Any>>("socialMetaTagParameters")
        if (socialParameters != null) {
            val socialBuilder = DynamicLink.SocialMetaTagParameters.Builder()
            (socialParameters["description"] as? String)?.let { socialBuilder.setDescription(it) }
            (socialParameters["imageUrl"] as? String)?.let {
                socialBuilder.setImageUrl(Uri.parse(it))
            }
            (socialParameters["title"] as? String)?.let { socialBuilder.setTitle(it) }
            dynamicLinkBuilder.setSocialMetaTagParameters(socialBuilder.build())
        }

        return dynamicLinkBuilder
    }
}
