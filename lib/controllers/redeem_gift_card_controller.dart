import 'package:flutter/material.dart';
import 'package:get/get.dart';

class RedeemGiftCardController extends GetxController {
  Rx<TextEditingController> giftCodeController = TextEditingController().obs;
  Rx<TextEditingController> giftPinController = TextEditingController().obs;

  @override
  void onInit() {
    // TODO: implement onInit
    super.onInit();
  }
}
