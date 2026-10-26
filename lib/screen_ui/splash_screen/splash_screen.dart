import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../constant/assets.dart';
import '../../controllers/splash_controller.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<SplashController>(
      init: SplashController(),
      builder: (controller) {
        return Scaffold(
          body: SizedBox.expand(
            child: Image.asset(AppAssets.splashScreen, fit: BoxFit.cover),
          ),
        );
      },
    );
  }
}
