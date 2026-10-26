import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OsmSearchPlaceController extends GetxController {
  Rx<TextEditingController> searchTxtController = TextEditingController().obs;
  RxList<SearchInfo> suggestionsList = <SearchInfo>[].obs;

  @override
  void onInit() {
    super.onInit();
    searchTxtController.value.addListener(() {
      _onChanged();
    });
  }

  void _onChanged() {
    fetchAddress(searchTxtController.value.text);
  }

  Future<void> fetchAddress(text) async {
    log(":: fetchAddress :: $text");
    try {
      String locale = 'en';
      SharedPreferences sp = await SharedPreferences.getInstance();
      if (sp.getString("languageCode") != null || sp.getString("languageCode")?.isNotEmpty == true) {
        locale = sp.getString("languageCode") ?? "en";
      }
      suggestionsList.value = await addressSuggestion(text, locale: locale);
    } catch (e) {
      log(e.toString());
    }
  }
}
