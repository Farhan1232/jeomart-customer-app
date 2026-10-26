import 'package:customer/controllers/theme_controller.dart';
import 'package:customer/themes/responsive.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'app_them_data.dart';

class RoundedButtonBorder extends StatelessWidget {
  final String title;
  final double? width;
  final double? height;
  final double? fontSizes;
  final double? radius;
  final Color? color;
  final Color? borderColor;
  final Color? textColor;
  final Widget? icon;
  final bool? isRight;
  final bool? isCenter;
  final Function()? onPress;

  const RoundedButtonBorder({
    super.key,
    required this.title,
    this.height,
    required this.onPress,
    this.width,
    this.radius,
    this.color,
    this.icon,
    this.fontSizes,
    this.textColor,
    this.isRight,
    this.borderColor,
    this.isCenter,
  });

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return InkWell(
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
        onPress?.call();
      },
      child: Container(
        width: Responsive.width(width ?? 100, context),
        height: Responsive.height(height ?? 6, context),
        decoration: ShapeDecoration(
          color: color ?? Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius ?? 50), side: BorderSide(color: borderColor ?? AppThemeData.danger300)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (isRight == false) Padding(padding: const EdgeInsets.only(right: 10, left: 0), child: icon),
            isCenter == true
                ? Text(title.tr, textAlign: TextAlign.center, style: AppThemeData.semiBoldTextStyle(fontSize: fontSizes ?? 14, color: textColor ?? AppThemeData.grey800))
                : Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: isRight == null ? 0 : 30),
                    child: Text(
                      title.tr,
                      textAlign: TextAlign.center,
                      style: AppThemeData.semiBoldTextStyle(fontSize: fontSizes ?? 14, color: textColor ?? (isDark ? AppThemeData.grey100 : AppThemeData.grey700)),
                    ),
                  ),
                ),
            if (isRight == true) Padding(padding: const EdgeInsets.only(left: 10, right: 20), child: icon),
          ],
        ),
      ),
    );
  }
}
