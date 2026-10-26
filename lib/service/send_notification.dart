import 'dart:convert';
import 'package:customer/constant/constant.dart';
import 'package:customer/models/notification_model.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart';

class SendNotification {
  static final _scopes = ['https://www.googleapis.com/auth/firebase.messaging'];

  static Future getCharacters() {
    return http.get(Uri.parse(Constant.jsonNotificationFileURL.toString())).timeout(Constant.mapRequestTimeout);
  }

  /// The service-account document, kept for the life of the process.
  ///
  /// It was downloaded again for every single notification. It is a fixed
  /// credential at a fixed URL; it does not change between two taps.
  static Map<String, dynamic>? _serviceAccount;

  /// The OAuth token that document buys, and the moment it stops being valid.
  ///
  /// `clientViaServiceAccount` is not a lookup: it signs a JWT - on this
  /// isolate - and exchanges it with Google over the network. Doing that once
  /// per notification put a full round trip, plus an RSA signature, in front of
  /// every push this app sends, and several of those sends are awaited on a
  /// screen the customer is watching. Google issues these for an hour; they are
  /// reused until a minute before they lapse.
  static String? _accessToken;
  static DateTime? _accessTokenExpiry;

  /// A token request already on its way, shared by every send that needs a
  /// token while it is. Accepting or cancelling a bid notifies several drivers
  /// at once, and with no token cached each of those sends used to download the
  /// service account, sign a JWT and exchange it separately.
  static Future<String>? _accessTokenInFlight;

  /// Test seam, and the way to force a re-read after a rotation.
  static void clearCredentialCache() {
    _serviceAccount = null;
    _accessToken = null;
    _accessTokenExpiry = null;
    _accessTokenInFlight = null;
  }

  static Future<String> getAccessToken() async {
    final String? cached = _accessToken;
    final DateTime? expiry = _accessTokenExpiry;
    if (cached != null && expiry != null && DateTime.now().isBefore(expiry)) {
      return cached;
    }

    final Future<String> inFlight = _accessTokenInFlight ??= _fetchAccessToken();
    try {
      return await inFlight;
    } finally {
      // Settled either way, so a failed request is tried afresh by the next send.
      if (identical(_accessTokenInFlight, inFlight)) _accessTokenInFlight = null;
    }
  }

  static Future<String> _fetchAccessToken() async {
    Map<String, dynamic> jsonData = _serviceAccount ?? {};
    if (jsonData.isEmpty) {
      await getCharacters().then((response) {
        jsonData = json.decode(response.body);
      });
      _serviceAccount = jsonData;
    }

    final serviceAccountCredentials = ServiceAccountCredentials.fromJson(jsonData);
    final client = await clientViaServiceAccount(serviceAccountCredentials, _scopes);
    final AccessToken token = client.credentials.accessToken;
    _accessToken = token.data;
    // A minute of slack, so a token that is about to lapse is not the one a
    // send goes out with.
    _accessTokenExpiry = token.expiry.toLocal().subtract(const Duration(minutes: 1));
    return token.data;
  }

  static Future<bool> sendFcmMessage(String type, String token, Map<String, dynamic>? payload) async {
    print(type);
    try {
      final String accessToken = await getAccessToken();
      if (kDebugMode) {
        debugPrint("accessToken=======>");
        debugPrint(accessToken);
      }
      NotificationModel? notificationModel = await FireStoreUtils.getNotificationContent(type);

      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/v1/projects/${Constant.senderId}/messages:send'),
        headers: <String, String>{'Content-Type': 'application/json', 'Authorization': 'Bearer $accessToken'},
        body: jsonEncode(<String, dynamic>{
          'message': {
            'token': token,
            'notification': {'body': notificationModel?.message ?? '', 'title': notificationModel?.subject ?? ''},
            'data': payload,
          },
        }),
      );

      if (kDebugMode) {
        debugPrint("Notification=======>");
        debugPrint(response.statusCode.toString());
        debugPrint(response.body);
      }
      return true;
    } catch (e) {
      debugPrint(e.toString());
      return false;
    }
  }

  static Future<bool> sendOneNotification({required String token, required String title, required String body, required Map<String, dynamic> payload}) async {
    try {
      final String accessToken = await getAccessToken();
      if (kDebugMode) {
        debugPrint("accessToken=======>");
        debugPrint(accessToken);
      }

      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/v1/projects/${Constant.senderId}/messages:send'),
        headers: <String, String>{'Content-Type': 'application/json', 'Authorization': 'Bearer $accessToken'},
        body: jsonEncode(<String, dynamic>{
          'message': {
            'token': token,
            'notification': {'body': body, 'title': title},
            'data': payload,
          },
        }),
      );

      if (kDebugMode) {
        debugPrint("Notification=======>");
        debugPrint(response.statusCode.toString());
        debugPrint(response.body);
      }
      return true;
    } catch (e) {
      debugPrint(e.toString());
      return false;
    }
  }

  static Future<bool> sendChatFcmMessage(String title, String message, String token, Map<String, dynamic>? payload) async {
    try {
      final String accessToken = await getAccessToken();
      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/v1/projects/${Constant.senderId}/messages:send'),
        headers: <String, String>{'Content-Type': 'application/json', 'Authorization': 'Bearer $accessToken'},
        body: jsonEncode(<String, dynamic>{
          'message': {
            'token': token,
            'notification': {'body': message, 'title': title},
            'data': payload,
          },
        }),
      );
      if (kDebugMode) {
        debugPrint("Notification=======>");
        debugPrint(response.statusCode.toString());
        debugPrint(response.body);
      }
      return true;
    } catch (e) {
      print(e);
      return false;
    }
  }
}
