import 'package:customer/screen_ui/location_enable_screens/location_permission_screen.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../constant/constant.dart';
import '../models/user_model.dart';
import '../screen_ui/auth_screens/login_screen.dart';
import '../screen_ui/auth_screens/sign_up_screen.dart';
import '../screen_ui/service_home_screen/service_list_screen.dart';
import '../service/fire_store_utils.dart';
import '../utils/notification_service.dart';

class OtpVerifyController extends GetxController {
  /// Use a normal controller (NOT obs)
  final Rx<PinInputController> otpController = PinInputController().obs;

  /// Reactive Strings
  final RxString countryCode = "".obs;
  final RxString countryISOCode = "".obs;
  final RxString phoneNumber = "".obs;
  final RxString verificationId = "".obs;
  RxInt resendToken = 0.obs;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void onInit() {
    super.onInit();

    final args = Get.arguments ?? {};

    countryCode.value = args['countryCode'] ?? "";
    countryISOCode.value = args['countryISOCode'] ?? "";
    phoneNumber.value = args['phoneNumber'] ?? "";
    verificationId.value = args['verificationId'] ?? "";
  }

  Future<bool> sendOTP() async {
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: countryCode.value + phoneNumber.value,
      verificationCompleted: (PhoneAuthCredential credential) {},
      verificationFailed: (FirebaseAuthException e) {},
      codeSent: (String verificationId0, int? resendToken0) async {
        verificationId.value = verificationId0;
        resendToken.value = resendToken0!;
        ShowToastDialog.showToast("OTP sent".tr);
      },
      timeout: const Duration(seconds: 25),
      forceResendingToken: resendToken.value,
      codeAutoRetrievalTimeout: (String verificationId0) {
        verificationId0 = verificationId.value;
      },
    );
    return true;
  }

  void verifyOtp() async {
    if (otpController.value.text.length != 6) {
      ShowToastDialog.showToast("Enter valid 6-digit OTP".tr);
      return;
    }

    try {
      ShowToastDialog.showLoader("Verifying OTP...".tr);

      final credential = PhoneAuthProvider.credential(verificationId: verificationId.value, smsCode: otpController.value.text.trim());

      final fcmToken = await NotificationService.getToken();
      final result = await _auth.signInWithCredential(credential);

      if (result.additionalUserInfo?.isNewUser == true) {
        final userModel = UserModel(id: result.user!.uid, countryCode: countryCode.value, countryISOCode: countryISOCode.value, phoneNumber: phoneNumber.value, fcmToken: fcmToken, active: true);
        ShowToastDialog.closeLoader();
        Get.to(() => const SignUpScreen(), arguments: {'type': 'mobileNumber', 'userModel': userModel});
        return;
      }

      final exists = await FireStoreUtils.userExistOrNot(result.user!.uid);
      ShowToastDialog.closeLoader();

      if (!exists) {
        final userModel = UserModel(id: result.user!.uid, countryCode: countryCode.value, countryISOCode: countryISOCode.value, phoneNumber: phoneNumber.value, fcmToken: fcmToken);
        Get.off(() => const SignUpScreen(), arguments: {'type': 'mobileNumber', 'userModel': userModel});
        return;
      }

      final userModel = await FireStoreUtils.getUserProfile(result.user!.uid);
      if (userModel == null || userModel.role != 'customer') {
        await _auth.signOut();
        Get.offAll(() => const LoginScreen());
        return;
      }

      if (userModel.active == false) {
        ShowToastDialog.showToast("This user is disabled".tr);
        await _auth.signOut();
        Get.offAll(() => const LoginScreen());
        return;
      }

      userModel.fcmToken = fcmToken;
      await FireStoreUtils.updateUser(userModel);

      if (userModel.shippingAddress?.isNotEmpty ?? false) {
        final defaultAddress = userModel.shippingAddress!.firstWhere((e) => e.isDefault == true, orElse: () => userModel.shippingAddress!.first);
        Constant.selectedLocation = defaultAddress;

        Get.offAll(() => const ServiceListScreen());
      } else {
        Get.offAll(() => const LocationPermissionScreen());
      }
    } catch (e) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Invalid OTP or Verification Failed".tr);
    }
  }

  String maskPhoneNumber(String phone) {
    if (phone.length < 4) return phone;

    final first = phone.substring(0, 2);
    final last = phone.substring(phone.length - 2);
    return "$first*** ***$last";
  }

  @override
  void dispose() {
    otpController.value.dispose();
    // TODO: implement dispose
    super.dispose();
  }
}
