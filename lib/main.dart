import 'package:customer/screen_ui/splash_screen/splash_screen.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/service/localization_service.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:customer/themes/easy_loading_config.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/utils/preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'controllers/global_setting_controller.dart';
import 'controllers/theme_controller.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final firebaseApp = await _initializeFirebase();

  if (currentEnv == FirebaseEnv.defaultDb) {
    FireStoreUtils.instance.init(firebaseApp);
  } else {
    // here i need to set original id ?
    FireStoreUtils.instance.init(firebaseApp, databaseId: 'staging'); // pass databaseId if named DB
  }

  await Preferences.initPref();
  // Before the first frame: the map every screen draws is configured over the
  // network, and a screen built before that read lands has to draw something.
  Constant.restoreMapSettings();

  Get.put(ThemeController());
  await configEasyLoading();

  runApp(MyApp());
}

Future<FirebaseApp> _initializeFirebase() async {
  try {
    return await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (error) {
    // On iOS the native Firebase app survives a Flutter hot restart. If Dart
    // initialization previously failed, reuse that valid native default app.
    if (error.code == 'duplicate-app') {
      return Firebase.app();
    }
    rethrow;
  }
}

class MyApp extends StatelessWidget {
  MyApp({super.key});

  final themeController = Get.find<ThemeController>();

  @override
  Widget build(BuildContext context) {
    Get.put(ThemeController());
    return Obx(
      () => GetMaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, child) {
          return SafeArea(bottom: true, top: false, child: EasyLoading.init()(context, child));
        },
        translations: LocalizationService(),
        locale: LocalizationService.locale,
        fallbackLocale: LocalizationService.locale,
        themeMode: themeController.themeMode,
        theme: ThemeData(
          scaffoldBackgroundColor: AppThemeData.surface,
          textTheme: TextTheme(bodyLarge: TextStyle(color: AppThemeData.grey900)),
          appBarTheme: AppBarTheme(backgroundColor: AppThemeData.surface, foregroundColor: AppThemeData.grey900, iconTheme: IconThemeData(color: AppThemeData.grey900)),
          bottomNavigationBarTheme: BottomNavigationBarThemeData(
            backgroundColor: AppThemeData.surface,
            selectedItemColor: AppThemeData.primary300,
            unselectedItemColor: AppThemeData.grey600,
            selectedLabelStyle: TextStyle(fontFamily: AppThemeData.bold, fontSize: 12),
            unselectedLabelStyle: TextStyle(fontFamily: AppThemeData.bold, fontSize: 12),
            type: BottomNavigationBarType.fixed,
          ),
        ),
        darkTheme: ThemeData(
          scaffoldBackgroundColor: AppThemeData.surfaceDark,
          textTheme: TextTheme(bodyLarge: TextStyle(color: AppThemeData.greyDark900)),
          appBarTheme: AppBarTheme(backgroundColor: AppThemeData.surfaceDark, foregroundColor: AppThemeData.greyDark900, iconTheme: IconThemeData(color: AppThemeData.greyDark900)),
          bottomNavigationBarTheme: BottomNavigationBarThemeData(
            backgroundColor: AppThemeData.grey900,
            selectedItemColor: AppThemeData.primary300,
            unselectedItemColor: AppThemeData.grey300,
            selectedLabelStyle: TextStyle(fontFamily: AppThemeData.bold, fontSize: 12),
            unselectedLabelStyle: TextStyle(fontFamily: AppThemeData.bold, fontSize: 12),
            type: BottomNavigationBarType.fixed,
          ),
        ),
        home: GetBuilder<GlobalSettingController>(
          init: GlobalSettingController(),
          builder: (context) {
            return const SplashScreen();
          },
        ),
      ),
    );
  }
}
