import 'package:shared_preferences/shared_preferences.dart';

class Preferences {
  static const isFinishOnBoardingKey = "isFinishOnBoardingKey";
  static const isLogin = "isLogin";
  static const accessToken = "accessToken";
  static const userData = "userData";
  static const themKey = "themKey";
  static const languageCodeKey = 'languageCodeKey';
  static const zipcode = 'zipcode';
  static const foodDeliveryType = "foodDeliveryType";
  static const payFastSettings = "payFastSettings";
  static const mercadoPago = "MercadoPago";
  static const paypalSettings = "paypalSettings";
  static const stripeSettings = "stripeSettings";
  static const flutterWave = "flutterWave";
  static const payStack = "payStack";
  static const paytmSettings = "PaytmSettings";
  static const walletSettings = "walletSettings";
  static const razorpaySettings = "razorpaySettings";
  static const codSettings = "CODSettings";
  static const midTransSettings = "midTransSettings";
  static const orangeMoneySettings = "orangeMoneySettings";
  static const xenditSettings = "xenditSettings";

  static const isClickOnNotification = "isClickOnNotification";

  /// The map the app draws, as the admin last set it in `settings/DriverNearBy`.
  ///
  /// Remembered on the device because those two values are read over the
  /// network at launch, and every screen that draws a map picks its map from
  /// them the first time it builds - before that read can have landed on a
  /// slow connection.
  static const selectedMapTypeKey = "selectedMapTypeKey";
  static const mapTypeKey = "mapTypeKey";

  static late SharedPreferences pref;

  static Future<void> initPref() async {
    pref = await SharedPreferences.getInstance();
  }

  /// Get boolean safely, fallback if stored value is string
  static bool getBoolean(String key) {
    final value = pref.get(key);
    if (value is bool) return value;
    if (value is String) {
      // fallback for old string "Dark"/"Light"
      return value.toLowerCase() == "dark";
    }
    return false;
  }

  static Future<void> setBoolean(String key, bool value) async {
    await pref.setBool(key, value);
  }

  static String getString(String key, {String? defaultValue}) {
    return pref.getString(key) ?? defaultValue ?? "";
  }

  static Future<void> setString(String key, String value) async {
    await pref.setString(key, value);
  }

  static int getInt(String key) {
    return pref.getInt(key) ?? 0;
  }

  static Future<void> setInt(String key, int value) async {
    await pref.setInt(key, value);
  }

  static Future<void> clearSharPreference() async {
    await pref.clear();
  }

  static Future<void> clearKeyData(String key) async {
    await pref.remove(key);
  }
}
