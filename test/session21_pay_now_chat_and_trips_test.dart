// Session 21: the three things the client reported in the customer app on
// 9 September.
//
//   * "when the customer click on Pay Now It goes to main customer app screen
//     and everything vanish";
//   * "pressing back button in customer app from chats directly crash the app";
//   * "you did not changed the name of trips to Available Trips".

import 'dart:io';

import 'package:customer/controllers/chat_controller.dart';
import 'package:customer/controllers/help_support_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final String booking = File('lib/controllers/cab_booking_controller.dart').readAsStringSync();
  final String pagination = File('lib/widget/firebase_pagination/src/firestore_pagination.dart').readAsStringSync();
  final String chatScreen = File('lib/screen_ui/multi_vendor_service/chat_screens/chat_screen.dart').readAsStringSync();
  final String english = File('lib/lang/app_en.dart').readAsStringSync();

  group('Pay Now stays on the ride', () {
    // `Pay Now` on the live-ride screen opens neither a bottom sheet nor a
    // payment page, so the two `Get.back()` calls in the cash branch popped two
    // real screens and landed the customer on the service list, mid-ride. The
    // gateway branch below still pops once - there, its payment page is what
    // closes - so the two branches are checked separately.
    final int codBranch = booking.indexOf('if (selectedPaymentMethod.value == PaymentGateway.cod.name) {');
    final int elseBranch = booking.indexOf('    } else {', codBranch);
    final String cod = booking.substring(codBranch, elseBranch);

    test('the cash branch pops nothing', () {
      expect(codBranch, greaterThan(-1));
      expect(cod.contains('Get.back()'), isFalse);
    });

    test('the cash branch still records the choice', () {
      expect(cod.contains('currentOrder.value.paymentMethod = selectedPaymentMethod.value;'), isTrue);
      expect(cod.contains('FireStoreUtils.cabOrderPlace(currentOrder.value)'), isTrue);
    });

    test('it says what actually happens next', () {
      // Cash is settled with the driver, who confirms it on their own screen.
      // "Payment method changed" described a different flow's side effect.
      expect(cod.contains('Please pay the fare to your driver in cash'), isTrue);
      expect(english.contains("'Please pay the fare to your driver in cash':"), isTrue);
    });

    test('the gateway branch still confirms, and now closes only what is open', () {
      // Session 23 corrects this test.
      //
      // It used to assert a bare `Get.back();` here, on Session 21's reasoning
      // that "the gateway branch pops once because there the payment page is
      // what closes". That reasoning does not hold on this screen:
      // `PayFastScreen`, `PayStackScreen` and `MercadoPagoScreen` each close
      // themselves with `Get.back(result: ...)` before the awaiting callback
      // runs, and Stripe and Razorpay push no route at all. So by the time this
      // line ran there was usually nothing left to close and the pop landed on
      // the ride screen - ejecting a customer who had just paid, which is the
      // same fault the cash branch above was fixed for.
      //
      // `SafePop.popUnlessCurrent` keeps the pop where a payment page really is
      // still open and skips it where it is not.
      final String rest = booking.substring(elseBranch, booking.indexOf('CabOrderModel buildOrderModel()'));
      expect(rest.contains('ShowToastDialog.showToast("Payment successfully".tr);'), isTrue);
      expect(rest.contains('SafePop.popUnlessCurrent'), isTrue);
      expect(rest.contains('Get.back();'), isFalse, reason: 'a bare pop here ejects the customer from their ride');
    });
  });

  group('leaving a chat', () {
    test('the paginator disposes only the controllers it made', () {
      // It was disposing the `ScrollController` handed to it by the chat and
      // Help & Support screens, which belongs to their GetX controller and is
      // still in use afterwards.
      expect(pagination.contains('if (_ownsController) _controller.dispose();'), isTrue);
      expect(pagination.contains('if (_ownsPageController) _pageController.dispose();'), isTrue);
      expect(pagination.contains('bool get _ownsController => widget.controller == null;'), isTrue);
    });

    test('a snapshot landing after the pop does not call setState', () {
      final int load = pagination.indexOf('Future<void> _loadDocuments({bool getMore = true}) async {');
      expect(load, greaterThan(-1));
      final String body = pagination.substring(load, load + 400);
      expect(body.contains('if (!mounted) return;'), isTrue);
      // The top-up scheduled for the next frame outlives the route too.
      expect(pagination.contains('addPostFrameCallback((_) {\n        if (!mounted) return;'), isTrue);
    });

    test('the send sites no longer reach into the scroll position themselves', () {
      expect(chatScreen.contains('scrollController.value.position.minScrollExtent'), isFalse);
      expect('scrollToLatest();'.allMatches(chatScreen).isNotEmpty, isTrue);
    });

    test("the thread's seen listener is stopped with the screen", () {
      // It was never stopped anywhere: `stopSeenForOrderListener` had no
      // callers, so every chat opened left a live listener marking messages
      // read in a thread the customer had left.
      final String chatController = File('lib/controllers/chat_controller.dart').readAsStringSync();
      final String utils = File('lib/service/fire_store_utils.dart').readAsStringSync();
      expect(utils.contains('static void stopSeenForOrderListener()'), isTrue);
      expect(chatController.contains('FireStoreUtils.stopSeenForOrderListener();'), isTrue);
    });

    testWidgets('the scroll that follows a sent message survives the screen closing', (WidgetTester tester) async {
      // The half second is the round trip the message needs. A back press
      // inside it used to leave the timer reading `position` on a controller
      // with nothing attached, which throws.
      final ChatController controller = ChatController();
      controller.scrollToLatest();
      controller.onClose();

      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Help & Support gets the same guard', (WidgetTester tester) async {
      final HelpSupportController controller = HelpSupportController();
      controller.scrollToLatest();

      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });
  });

  group('the cab bar', () {
    final String dashboard = File('lib/screen_ui/cab_service_screens/cab_dashboard_screen.dart').readAsStringSync();

    test('the Trips tab is named after the screen it opens', () {
      expect(dashboard.contains("return 'Available Trips'.tr;"), isTrue);
      expect(dashboard.contains("return 'Trips'.tr;"), isFalse);
      // The phrase already had a translation - it is the heading of the screen
      // this tab opens - so the rename needed no new key.
      expect(english.contains("'Available Trips': 'Available Trips',"), isTrue);
    });

    test('a long label is sized to fit rather than painted over its neighbour', () {
      // `BottomNavigationBar` neither shrinks nor ellipsises a label that does
      // not fit, so the size is measured against the width one tab gets.
      expect(dashboard.contains('MediaQuery.sizeOf(context).width / tabs.length'), isTrue);
      expect(dashboard.contains('.clamp(8.0, 12.0)'), isTrue);
      // And the estimate has a backstop: a label the estimate got wrong is
      // ellipsised rather than painted over the tab beside it.
      expect(dashboard.contains('overflow: TextOverflow.ellipsis'), isTrue);
    });
  });
}
