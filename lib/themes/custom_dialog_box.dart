import 'package:customer/themes/responsive.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/theme_controller.dart';
import 'app_them_data.dart';

class CustomDialogBox extends StatelessWidget {
  final String title, descriptions, positiveString, negativeString;
  final Widget? img;
  final Function() positiveClick;
  final Function() negativeClick;

  const CustomDialogBox({
    super.key,
    required this.title,
    required this.descriptions,
    required this.img,
    required this.positiveClick,
    required this.negativeClick,
    required this.positiveString,
    required this.negativeString,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeController themeController = Get.find<ThemeController>();

    return Obx(() {
      final isDark = themeController.isDark.value;

      return Dialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), elevation: 0, backgroundColor: Colors.transparent, child: contentBox(context, isDark));
    });
  }

  Widget contentBox(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(shape: BoxShape.rectangle, color: isDark ? AppThemeData.greyDark100 : AppThemeData.grey100, borderRadius: BorderRadius.circular(20)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          img ?? const SizedBox(),
          const SizedBox(height: 20),
          if (title.isNotEmpty) Text(title.tr, style: AppThemeData.boldTextStyle(fontSize: 20, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
          const SizedBox(height: 5),
          if (descriptions.isNotEmpty)
            Text(descriptions.tr, textAlign: TextAlign.center, style: AppThemeData.regularTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: negativeClick,
                  child: Container(
                    width: Responsive.width(100, context),
                    height: Responsive.height(5, context),
                    decoration: BoxDecoration(color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900, borderRadius: BorderRadius.circular(200)),
                    child: Center(
                      child: Text(negativeString.tr, textAlign: TextAlign.center, style: AppThemeData.mediumTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark100 : AppThemeData.grey100)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: positiveClick,
                  child: Container(
                    width: Responsive.width(100, context),
                    height: Responsive.height(5, context),
                    decoration: BoxDecoration(color: AppThemeData.success300, borderRadius: BorderRadius.circular(200)),
                    child: Center(child: Text('Confirm'.tr, textAlign: TextAlign.center, style: AppThemeData.mediumTextStyle(fontSize: 14, color: AppThemeData.grey100))),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
