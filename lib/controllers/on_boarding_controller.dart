import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/on_boarding_model.dart';
import '../service/fire_store_utils.dart';

class OnboardingController extends GetxController {
  RxInt currentPage = 0.obs;
  late PageController pageController;

  RxBool isLoading = true.obs;
  RxList<OnBoardingModel> onboardingList = <OnBoardingModel>[].obs;

  @override
  void onInit() {
    super.onInit();
    pageController = PageController();
    getOnBoardingData();
  }

  void nextPage() {
    if (currentPage.value < onboardingList.length - 1) {
      pageController.nextPage(duration: 300.milliseconds, curve: Curves.ease);
    }
  }

  void onPageChanged(int index) {
    currentPage.value = index;
  }

  Future<void> getOnBoardingData() async {
    isLoading.value = true;
    await FireStoreUtils.getOnBoardingList().then((value) {
      onboardingList.value = value;
    });
    isLoading.value = false;
  }

  @override
  void onClose() {
    pageController.dispose();
    super.onClose();
  }
}
