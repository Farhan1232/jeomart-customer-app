import 'package:flutter/material.dart';
import 'app_them_data.dart';

class Styles {
  static ThemeData themeData(bool isDarkTheme, BuildContext context) {
    return ThemeData(
      scaffoldBackgroundColor: isDarkTheme ? AppThemeData.surfaceDark : AppThemeData.surface,
      primaryColor: isDarkTheme ? AppThemeData.dangerDark300 : AppThemeData.danger300,
      brightness: isDarkTheme ? Brightness.dark : Brightness.light,
      appBarTheme: AppBarTheme(
        backgroundColor: isDarkTheme ? AppThemeData.grey900 : AppThemeData.grey50,
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: isDarkTheme ? AppThemeData.greyDark100 : AppThemeData.grey100,
        dialTextStyle: TextStyle(fontWeight: FontWeight.bold, color: isDarkTheme ? AppThemeData.greyDark100 : AppThemeData.grey100),
        dialTextColor: isDarkTheme ? AppThemeData.greyDark50 : AppThemeData.grey50,
        hourMinuteTextColor: isDarkTheme ? AppThemeData.greyDark100 : AppThemeData.grey100,
        dayPeriodTextColor: isDarkTheme ? AppThemeData.greyDark100 : AppThemeData.grey100,
      ),
    );
  }
}
