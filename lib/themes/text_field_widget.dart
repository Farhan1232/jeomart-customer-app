import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../controllers/theme_controller.dart';
import 'app_them_data.dart';

class TextFieldWidget extends StatefulWidget {
  final String? title;
  final String hintText;
  final TextEditingController? controller;
  final Widget? prefix;
  final Widget? suffix;
  final bool? enable;
  final bool? readOnly;
  final bool? obscureText;
  final int? maxLine;
  final TextInputType? textInputType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onchange;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final ValueChanged<String>? onFieldSubmitted;
  final Color? hintColor;
  final Color? backgroundColor;
  final Color? borderColor;

  const TextFieldWidget({
    super.key,
    this.textInputType,
    this.enable,
    this.readOnly,
    this.obscureText,
    this.prefix,
    this.suffix,
    this.title,
    required this.hintText,
    required this.controller,
    this.maxLine,
    this.inputFormatters,
    this.onchange,
    this.textInputAction,
    this.focusNode,
    this.onFieldSubmitted,
    this.borderColor,
    this.hintColor,
    this.backgroundColor,
  });

  @override
  State<TextFieldWidget> createState() => _TextFieldWidgetState();
}

class _TextFieldWidgetState extends State<TextFieldWidget> {
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(() {
      setState(() {});
    });
  }

  // @override
  // void dispose() {
  //   if (widget.focusNode == null) {
  //     _focusNode.dispose();
  //   }
  //   super.dispose();
  // }

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;

    final borderColor = widget.borderColor ?? (_focusNode.hasFocus ? (isDark ? AppThemeData.greyDark400 : AppThemeData.grey400) : (isDark ? AppThemeData.greyDark200 : AppThemeData.grey200));

    final fillColor =
        widget.backgroundColor ?? (isDark ? (_focusNode.hasFocus ? AppThemeData.greyDark50 : AppThemeData.greyDark100) : (_focusNode.hasFocus ? AppThemeData.grey100 : Colors.transparent));

    final textColor = isDark ? AppThemeData.greyDark900 : AppThemeData.grey900;

    final hintColor = widget.hintColor ?? (isDark ? AppThemeData.grey400 : AppThemeData.greyDark400);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.title != null) ...[
          Text(widget.title!.tr, style: AppThemeData.boldTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark800 : AppThemeData.grey800)),
          const SizedBox(height: 5),
        ],
        TextFormField(
          keyboardType: widget.textInputType ?? TextInputType.text,
          textCapitalization: TextCapitalization.sentences,
          controller: widget.controller,
          maxLines: widget.maxLine ?? 1,
          focusNode: _focusNode,
          textInputAction: widget.textInputAction ?? TextInputAction.done,
          inputFormatters: widget.inputFormatters,
          obscureText: widget.obscureText ?? false,
          obscuringCharacter: '●',
          onChanged: widget.onchange,
          readOnly: widget.readOnly ?? false,
          onFieldSubmitted: widget.onFieldSubmitted,
          style: AppThemeData.semiBoldTextStyle(color: textColor),
          decoration: InputDecoration(
            errorStyle: const TextStyle(color: Colors.red),
            filled: true,
            enabled: widget.enable ?? true,
            fillColor: fillColor,
            contentPadding: EdgeInsets.symmetric(vertical: widget.title == null ? 15 : (widget.enable == false ? 13 : 8), horizontal: 10),
            prefixIcon: widget.prefix,
            suffixIcon: widget.suffix,
            prefixIconConstraints: const BoxConstraints(minHeight: 20, minWidth: 20),
            suffixIconConstraints: const BoxConstraints(minHeight: 20, minWidth: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor, width: 1.2)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.red)),
            disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
            hintText: widget.hintText.tr,
            hintStyle: AppThemeData.regularTextStyle(fontSize: 14, color: hintColor),
          ),
        ),
      ],
    );
  }
}
