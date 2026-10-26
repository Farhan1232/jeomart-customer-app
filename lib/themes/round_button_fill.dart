import 'package:customer/themes/responsive.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'app_them_data.dart';

class RoundedButtonFill extends StatelessWidget {
  final String title;
  final double? width;
  final double? height;
  final double? fontSizes;
  final double? borderRadius;
  final Color? color;
  final Color? textColor;
  final Widget? icon;
  final bool? isRight;
  final bool? isCenter;
  final VoidCallback? onPress;

  // final Function()? onPress;

  const RoundedButtonFill({
    super.key,
    required this.title,
    this.borderRadius,
    this.height,
    required this.onPress,
    this.width,
    this.color,
    this.isCenter,
    this.icon,
    this.fontSizes,
    this.textColor,
    this.isRight,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(borderRadius ?? 50),
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
        onPress?.call();
      },
      child: Container(
        width: Responsive.width(width ?? 100, context),
        height: Responsive.height(height ?? 6, context),
        decoration: ShapeDecoration(color: color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius ?? 50))),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (isRight == false) Padding(padding: const EdgeInsets.only(right: 10, left: 10), child: icon),
            isCenter == true
                ? Text(title.tr, textAlign: TextAlign.center, style: AppThemeData.semiBoldTextStyle(fontSize: fontSizes ?? 16, color: textColor ?? AppThemeData.grey50))
                : Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: isRight == null ? 0 : 30),
                    child: Text(title.tr, textAlign: TextAlign.center, style: AppThemeData.semiBoldTextStyle(fontSize: fontSizes ?? 16, color: textColor ?? AppThemeData.grey50)),
                  ),
                ),
            if (isRight == true) Padding(padding: const EdgeInsets.only(left: 10, right: 10), child: icon),
          ],
        ),
      ),
    );
  }
}
