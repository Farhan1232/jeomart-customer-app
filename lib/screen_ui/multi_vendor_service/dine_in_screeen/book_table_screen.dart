import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/dine_in_restaurant_details_controller.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:customer/themes/responsive.dart';
import 'package:customer/themes/round_button_fill.dart';
import 'package:customer/themes/text_field_widget.dart';
import 'package:customer/utils/network_image_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../controllers/theme_controller.dart';

class BookTableScreen extends StatelessWidget {
  const BookTableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: DineInRestaurantDetailsController(),
      builder: (controller) {
        return Scaffold(
          appBar: AppBar(
            centerTitle: false,
            titleSpacing: 0,
            backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
            title: Text("Book Table".tr, style: TextStyle(fontSize: 16, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.medium, fontWeight: FontWeight.w500)),
          ),
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: ShapeDecoration(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              "Numbers of Guests".tr,
                              style: TextStyle(fontSize: 16, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.medium, fontWeight: FontWeight.w500),
                            ),
                          ),
                          Container(
                            height: Responsive.height(4, context),
                            decoration: ShapeDecoration(
                              color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(200), side: BorderSide(color: isDark ? AppThemeData.grey600 : AppThemeData.grey300)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 5),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  InkWell(
                                    onTap: () {
                                      if (controller.noOfQuantity.value != 1) {
                                        controller.noOfQuantity.value -= 1;
                                      }
                                    },
                                    child: const Icon(Icons.remove),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    child: Text(
                                      controller.noOfQuantity.toString(),
                                      textAlign: TextAlign.start,
                                      maxLines: 1,
                                      style: TextStyle(
                                        fontSize: 16,
                                        overflow: TextOverflow.ellipsis,
                                        fontFamily: AppThemeData.medium,
                                        fontWeight: FontWeight.w500,
                                        color: isDark ? AppThemeData.grey100 : AppThemeData.grey800,
                                      ),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () {
                                      controller.noOfQuantity.value += 1;
                                    },
                                    child: Icon(Icons.add, color: AppThemeData.primary300),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: ShapeDecoration(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "When are you visiting?".tr,
                            style: TextStyle(fontSize: 16, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w500),
                          ),
                          SizedBox(
                            height: 120,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              physics: const BouncingScrollPhysics(),
                              itemCount: controller.dateList.length,
                              scrollDirection: Axis.horizontal,
                              itemBuilder: (context, index) {
                                return Stack(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 8),
                                      child: GestureDetector(
                                        onTap: () {
                                          controller.selectedDate.value = controller.dateList[index].date;
                                          controller.timeSet(controller.dateList[index].date);
                                        },
                                        child: Obx(
                                          () => Container(
                                            width: 100,
                                            height: 90,
                                            decoration: ShapeDecoration(
                                              shape: RoundedRectangleBorder(
                                                side: BorderSide(
                                                  width: 1,
                                                  color:
                                                      controller.selectedDate.value == controller.dateList[index].date
                                                          ? AppThemeData.primary300
                                                          : isDark
                                                          ? AppThemeData.grey800
                                                          : AppThemeData.grey100,
                                                ),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.all(8.0),
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                crossAxisAlignment: CrossAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    Constant.calculateDifference(controller.dateList[index].date.toDate()) == 0
                                                        ? "Today".tr
                                                        : Constant.calculateDifference(controller.dateList[index].date.toDate()) == 1
                                                        ? "Tomorrow".tr
                                                        : DateFormat('EEE').format(controller.dateList[index].date.toDate()),
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: isDark ? AppThemeData.grey400 : AppThemeData.grey500,
                                                      fontFamily: AppThemeData.regular,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                  Text(
                                                    DateFormat('d MMM').format(controller.dateList[index].date.toDate()).toString(),
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      color: isDark ? AppThemeData.grey400 : AppThemeData.grey500,
                                                      fontFamily: AppThemeData.semiBold,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 10,
                                      left: 0,
                                      right: 0,
                                      child: Center(
                                        child: RoundedButtonFill(
                                          title: "${controller.dateList[index].discountPer}%".tr,
                                          color: AppThemeData.primary300,
                                          textColor: AppThemeData.grey50,
                                          width: 12,
                                          height: 3,
                                          onPress: () {},
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "Select time slot and scroll to see offers".tr,
                            style: TextStyle(fontSize: 16, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            decoration: ShapeDecoration(
                              shape: RoundedRectangleBorder(side: BorderSide(width: 1, color: isDark ? AppThemeData.grey600 : AppThemeData.grey300), borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                              child: Wrap(
                                spacing: 5.0,
                                children: <Widget>[
                                  ...controller.timeSlotList.map(
                                    (timeSlotList) => InputChip(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                      side: BorderSide.none,
                                      backgroundColor: isDark ? AppThemeData.grey800 : AppThemeData.grey100,
                                      selectedColor: AppThemeData.primary300,
                                      labelStyle: TextStyle(color: isDark ? AppThemeData.grey100 : AppThemeData.grey800),
                                      label: Text(
                                        DateFormat('hh:mm a').format(timeSlotList.time!),
                                        style: TextStyle(
                                          color:
                                              controller.selectedTimeSlot.value == DateFormat('hh:mm a').format(timeSlotList.time!)
                                                  ? AppThemeData.grey50
                                                  : isDark
                                                  ? AppThemeData.grey400
                                                  : AppThemeData.grey500,
                                          fontFamily: AppThemeData.medium,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      showCheckmark: false,
                                      selected: controller.selectedTimeSlot.value == DateFormat('hh:mm a').format(timeSlotList.time!),
                                      onSelected: (value) {
                                        controller.selectedTimeSlot.value = DateFormat('hh:mm a').format(timeSlotList.time!);
                                        controller.selectedTimeDiscount.value = timeSlotList.discountPer!;
                                        controller.selectedTimeDiscountType.value = timeSlotList.discountType!;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "Special Occasion".tr,
                          style: TextStyle(fontSize: 16, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w500),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          controller.selectedOccasion.value = "";
                        },
                        child: Text("Clear".tr, style: TextStyle(color: isDark ? AppThemeData.primary300 : AppThemeData.primary300, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: ShapeDecoration(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (int i = 0; i < controller.occasionList.length; i++)
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 0.0),
                              visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
                              dense: true,
                              title: Text(
                                controller.getLocalizedOccasion(controller.occasionList[i]),
                                style: TextStyle(fontSize: 16, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.medium, fontWeight: FontWeight.w500),
                              ),
                              leading: Radio<String>(
                                visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
                                value: controller.occasionList[i],
                                groupValue: controller.selectedOccasion.value,
                                activeColor: AppThemeData.primary300,
                                onChanged: (value) {
                                  controller.selectedOccasion.value = value!;
                                },
                              ),
                            ),
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 0.0),
                            visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
                            dense: true,
                            title: Text(
                              'Is this your first visit?'.tr,
                              style: TextStyle(fontSize: 16, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.medium, fontWeight: FontWeight.w500),
                            ),
                            leading: Checkbox(
                              visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
                              value: controller.firstVisit.value,
                              activeColor: AppThemeData.primary300,
                              onChanged: (value) {
                                controller.firstVisit.value = value!;
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Personal Details".tr,
                    style: TextStyle(fontSize: 16, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: ShapeDecoration(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          ClipOval(
                            child: NetworkImageWidget(
                              imageUrl: Constant.userModel!.profilePictureURL.toString(),
                              width: 50,
                              height: 50,
                              errorWidget: Image.asset(Constant.userPlaceHolder, fit: BoxFit.cover, width: 50, height: 50),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                Constant.userModel!.fullName(),
                                style: TextStyle(fontSize: 16, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w500),
                              ),
                              Text(
                                "${Constant.userModel!.email}",
                                style: TextStyle(fontSize: 12, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.medium, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Additional Requests".tr,
                    style: TextStyle(fontSize: 16, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 10),
                  TextFieldWidget(controller: controller.additionRequestController.value, hintText: 'Add message here....'.tr, maxLine: 5),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          bottomNavigationBar: Container(
            color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: RoundedButtonFill(
                title: "Book Now".tr,
                height: 5.5,
                color: AppThemeData.primary300,
                textColor: AppThemeData.grey50,
                fontSizes: 16,
                onPress: () async {
                  controller.orderBook();
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
