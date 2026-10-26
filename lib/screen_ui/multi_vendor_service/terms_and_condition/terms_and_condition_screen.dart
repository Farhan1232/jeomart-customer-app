import 'package:customer/constant/collection_name.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:customer/themes/round_button_fill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../controllers/theme_controller.dart';

class TermsAndConditionScreen extends StatefulWidget {
  final String? type;

  const TermsAndConditionScreen({super.key, this.type});

  @override
  State<TermsAndConditionScreen> createState() => _TermsAndConditionScreenState();
}

class _TermsAndConditionScreenState extends State<TermsAndConditionScreen> {
  String _content = "";
  bool _isLoading = true;

  bool get _isPrivacy => widget.type == "privacy";

  String get _fallbackUrl => _isPrivacy ? Constant.privacyPolicyUrl : Constant.termsAndConditionsUrl;

  @override
  void initState() {
    super.initState();
    _fetchContent();
  }

  /// Reads the policy text on demand - which is where the app now reads it at
  /// all.
  ///
  /// These two documents are 69.8 KB and 51.9 KB on the live project, and
  /// startup used to open a permanent listener on **both** of them, so every
  /// launch paid 122 KB for text almost nobody opens. That listener is gone;
  /// this screen's own read, which was always the primary source, is now the
  /// only read.
  ///
  /// What it fetches is written back into `Constant`, so the in-memory fallback
  /// below is still populated after the first visit - the offline case behaves
  /// exactly as it did, just without charging every launch for it.
  Future<void> _fetchContent() async {
    try {
      if (_isPrivacy) {
        final doc = await FireStoreUtils.fireStore.collection(CollectionName.settings).doc("privacyPolicy").get();
        if (doc.exists && doc.data() != null) {
          _content = doc.data()?["privacy_policy"] ?? "";
          if (_content.isNotEmpty) Constant.privacyPolicy = _content;
        }
        if (_content.isEmpty && Constant.privacyPolicy.isNotEmpty) {
          _content = Constant.privacyPolicy;
        }
      } else {
        final doc = await FireStoreUtils.fireStore.collection(CollectionName.settings).doc("termsAndConditions").get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          _content = data["terms_and_condition"] ?? data["termsAndConditions"] ?? "";
          if (_content.isNotEmpty) Constant.termsAndConditions = _content;
        }
        if (_content.isEmpty && Constant.termsAndConditions.isNotEmpty) {
          _content = Constant.termsAndConditions;
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _openInBrowser() async {
    final uri = Uri.parse(_fallbackUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return Scaffold(
      backgroundColor: isDark ? AppThemeData.grey50 : AppThemeData.grey50,
      appBar: AppBar(
        backgroundColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
        centerTitle: false,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        leading: InkWell(
          onTap: () {
            Get.back();
          },
          child: Icon(Icons.chevron_left_outlined, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900),
        ),
        title: Text(
          _isPrivacy ? "Privacy Policy".tr : "Terms & Conditions".tr,
          style: TextStyle(color: isDark ? AppThemeData.grey100 : AppThemeData.grey800, fontFamily: AppThemeData.bold, fontSize: 18),
        ),
        elevation: 0,
        bottom: PreferredSize(preferredSize: const Size.fromHeight(4.0), child: Container(color: isDark ? AppThemeData.grey700 : AppThemeData.grey200, height: 4.0)),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _content.trim().isEmpty
              ? _buildEmptyFallback(isDark)
              : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Html(shrinkWrap: true, data: _content),
                      const SizedBox(height: 16),
                      TextButton(onPressed: _openInBrowser, child: Text("View Online".tr, style: AppThemeData.semiBoldTextStyle(color: AppThemeData.info400))),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildEmptyFallback(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "No content available. Please view our policy online.".tr,
            textAlign: TextAlign.center,
            style: TextStyle(color: isDark ? AppThemeData.grey100 : AppThemeData.grey800, fontFamily: AppThemeData.medium, fontSize: 16),
          ),
          const SizedBox(height: 24),
          RoundedButtonFill(
            title: "View Online".tr,
            onPress: _openInBrowser,
            color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900,
            textColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
          ),
        ],
      ),
    );
  }
}
