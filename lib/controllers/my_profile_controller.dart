import 'dart:developer';
import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/theme_controller.dart';
import '../service/fire_store_utils.dart';
import 'package:customer/utils/preferences.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

class MyProfileController extends GetxController {
  RxBool isLoading = true.obs;

  RxString isDarkMode = "Light".obs; // For UI text
  RxBool isDarkModeSwitch = false.obs; // For switch widget

  @override
  void onInit() {
    getTheme();
    super.onInit();
  }

  void getTheme() {
    bool isDark = Preferences.getBoolean(Preferences.themKey);
    isDarkMode.value = isDark ? "Dark" : "Light";
    isDarkModeSwitch.value = isDark;
    isLoading.value = false;
  }

  void toggleDarkMode(bool value) {
    isDarkModeSwitch.value = value;
    isDarkMode.value = value ? "Dark" : "Light";
    Preferences.setBoolean(Preferences.themKey, value);

    // Update ThemeController for instant app theme change
    if (Get.isRegistered<ThemeController>()) {
      final themeController = Get.find<ThemeController>();
      themeController.isDark.value = value;
    }
  }

  // Delete user API
  Future<bool> deleteUserFromServer() async {
    var url = '${Constant.websiteUrl}/api/delete-user';
    try {
      var response = await http.post(Uri.parse(url), body: {'uuid': FireStoreUtils.getCurrentUid()});
      log("deleteUserFromServer :: ${response.body}");
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
