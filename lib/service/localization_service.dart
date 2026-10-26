import 'package:customer/lang/app_ar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../lang/app_en.dart';

class LocalizationService extends Translations {
  // Default locale
  static const locale = Locale('en', 'US');

  static final locales = [const Locale('en')];

  // Keys and their translations
  // Translations are separated maps in `lang` file
  @override
  Map<String, Map<String, String>> get keys => {'en_US': enUS, 'ar_AR': arAR};

  // Gets locale from language, and updates the locale
  void changeLocale(String lang) {
    Get.updateLocale(Locale(lang));
  }
}
