import 'package:customer/models/booking_entry.dart';
import 'package:customer/models/cab_order_model.dart';
import 'package:customer/models/user_model.dart';
import 'package:customer/payment/create_razor_pay_order_model.dart';
import 'package:customer/payment/rozorpay_conroller.dart';
import 'package:customer/screen_ui/auth_screens/login_screen.dart';
import 'package:customer/screen_ui/multi_vendor_service/chat_screens/driver_inbox_screen.dart';
import 'package:customer/screen_ui/multi_vendor_service/wallet_screen/wallet_screen.dart';
import 'package:customer/themes/round_button_fill.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:customer/widget/booked_trip_card.dart';
import 'package:customer/widget/load_more_listener.dart';
import 'package:get/get.dart';
import '../../constant/constant.dart';
import '../../controllers/my_cab_booking_controller.dart';
import '../../controllers/theme_controller.dart';
import '../../themes/app_them_data.dart';
import 'package:dotted_border/dotted_border.dart';

import 'cab_order_details.dart';
import 'package:customer/widget/tab_selection_listener.dart';

class MyCabBookingScreen extends StatelessWidget {
  const MyCabBookingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;

    return GetX(
      init: MyCabBookingController(),
      builder: (controller) {
        return DefaultTabController(
          // Re-created only when the app jumps to a tab by itself (after a
          // trip is booked); `initialIndex` is otherwise read once.
          key: ValueKey<int>(controller.tabJump.value),
          // length: controller.tabTitles.length,
          // initialIndex: controller.tabTitles.indexOf(controller.selectedTab.value),
          length: controller.tabKeys.length,
          initialIndex: controller.tabKeys.indexOf(controller.selectedTab.value),
          child: Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false,
              backgroundColor: AppThemeData.primary300,
              title: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [const SizedBox(width: 10), Text("Ride History".tr, style: AppThemeData.boldTextStyle(fontSize: 18, color: AppThemeData.grey900))]),
              ),
              // Messages. Chat itself was already built and already worked; the
              // only way in was the multi-vendor Profile screen, so a customer
              // who uses nothing but the taxi service could not reach a
              // conversation they were already having with their driver.
              //
              // This opens the SAME `DriverInboxScreen` that Profile opens - not
              // a second inbox - so there is one list of conversations and one
              // place they are read from.
              actions: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(right: 8, bottom: 10),
                  child: IconButton(
                    tooltip: "Messages".tr,
                    icon: const FaIcon(FontAwesomeIcons.solidComments, size: 20, color: AppThemeData.grey900),
                    onPressed: () => Get.to(const DriverInboxScreen()),
                  ),
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: TabBar(
                  isScrollable: false,
                  onTap: (index) {
                    controller.selectTab(controller.tabKeys[index]);
                  },
                  indicatorColor: AppThemeData.taxiBooking500,
                  labelColor: AppThemeData.taxiBooking500,
                  unselectedLabelColor: AppThemeData.taxiBooking500,
                  labelStyle: AppThemeData.boldTextStyle(fontSize: 14),
                  unselectedLabelStyle: AppThemeData.mediumTextStyle(fontSize: 14),
                  tabs:
                      controller.tabKeys
                          .map(
                            (key) => Tab(
                              child: SizedBox.expand(
                                child: Center(
                                  child: Text(
                                    controller.getLocalizedTabTitle(key),
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.visible, // 👈 show full text
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                ),
              ),
            ),
            body:
                controller.isLoading.value
                    ? Constant.loader()
                    : Constant.userModel == null
                    ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text("Please Log In to Continue".tr, style: TextStyle(color: isDark ? AppThemeData.grey100 : AppThemeData.grey800, fontSize: 22, fontFamily: AppThemeData.semiBold)),
                          const SizedBox(height: 5),
                          Text(
                            "You’re not logged in. Please sign in to access your account and explore all features.".tr,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey500, fontSize: 16, fontFamily: AppThemeData.bold),
                          ),
                          const SizedBox(height: 20),
                          RoundedButtonFill(
                            title: "Log in".tr,
                            width: 55,
                            height: 5.5,
                            color: AppThemeData.primary300,
                            textColor: AppThemeData.grey50,
                            onPress: () async {
                              Get.offAll(const LoginScreen());
                            },
                          ),
                        ],
                      ),
                    )
                    : TabSelectionListener(
                        // A swipe between tabs has to do what a tap does: tell the paginator
                        // which tab is on screen, so it tops the list up for that tab.
                        onChanged: (index) => controller.selectTab(controller.tabKeys[index]),
                        child: TabBarView(
                               children:
                                   controller.tabKeys.map((title) {
                                     // Both reads happen here, inside the GetX builder, and not in
                                     // `itemBuilder`: that runs during layout, after GetX has stopped
                                     // recording which observables this build depends on. A driver
                                     // profile that lands a moment later would otherwise never repaint
                                     // the card it belongs to.
                                     final Map<String, UserModel> tripDrivers = Map<String, UserModel>.from(controller.bookedTrips.drivers);
                                     final List<BookingEntry> entries = controller.getEntriesForTab(title);

                                     // Still topping the list up after the first page: say so,
                                     // rather than "No order found" for rows that are on their way.
                                     if (entries.isEmpty && controller.isFilling.value) {
                                       return const Center(child: LoadMoreIndicator());
                                     }

                                     if (entries.isEmpty) {
                                       return RefreshIndicator(
                                         // An empty tab has to stay refreshable. It used to be a bare
                                         // Center, which scrolls nowhere - so a tab that looked empty
                                         // offered the user no way to ask again.
                                         onRefresh: controller.refreshOrders,
                                         child: ListView(
                                           physics: const AlwaysScrollableScrollPhysics(),
                                           children: [
                                             SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                                             Center(child: Text("No order found".tr, style: AppThemeData.mediumTextStyle(color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900))),
                                           ],
                                         ),
                                       );
                                     }

                                     return LoadMoreListener(
                                       onLoadMore: controller.loadMoreOrders,
                                       child: RefreshIndicator(
                                         onRefresh: controller.refreshOrders,
                                         child: ListView.builder(
                                           padding: const EdgeInsets.all(16),
                                           itemCount: entries.length + (controller.hasMoreEntries ? 1 : 0),
                                           itemBuilder: (context, index) {
                                             if (index >= entries.length) {
                                               return const LoadMoreIndicator();
                                             }
                                             final BookingEntry entry = entries[index];
                                             // A full vehicle taken off a driver-posted trip. Same list,
                                             // its own card, because a trip has a driver to call and no
                                             // fare breakdown, OTP or payment to settle.
                                             if (entry.isTrip) {
                                               return BookedTripCard(
                                                 trip: entry.trip!,
                                                 driver: tripDrivers[entry.trip!.driverId ?? ''],
                                                 isDark: isDark,
                                               );
                                             }
                                             CabOrderModel order = entry.ride!;
                                             return GestureDetector(
                                               onTap: () {
                                                 Get.to(() => CabOrderDetails(), arguments: {"cabOrderModel": order});
                                               },
                                               child: Container(
                                                 margin: const EdgeInsets.only(bottom: 16),
                                                 padding: const EdgeInsets.all(16),
                                                 decoration: BoxDecoration(
                                                   color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                                                   borderRadius: BorderRadius.circular(15),
                                                   border: Border.all(color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200),
                                                 ),
                                                 child: Column(
                                                   crossAxisAlignment: CrossAxisAlignment.start,
                                                   children: [
                                                     Text(
                                                       "${'Booking Date:'.tr} ${controller.formatDate(order.scheduleDateTime!)}".tr,
                                                       textAlign: TextAlign.start,
                                                       style: TextStyle(fontFamily: AppThemeData.semiBold, fontSize: 18, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900),
                                                     ),
                                                     Row(
                                                       crossAxisAlignment: CrossAxisAlignment.start,
                                                       children: [
                                                         Column(
                                                           children: [
                                                             Icon(Icons.stop_circle_outlined, color: Colors.green),
                                                             DottedBorder(
                                                               options: CustomPathDottedBorderOptions(
                                                                 color: Colors.grey.shade400,
                                                                 strokeWidth: 2,
                                                                 dashPattern: [4, 4],
                                                                 customPath:
                                                                     (size) =>
                                                                         Path()
                                                                           ..moveTo(size.width / 2, 0)
                                                                           ..lineTo(size.width / 2, size.height),
                                                               ),
                                                               child: const SizedBox(width: 20, height: 55),
                                                             ),
                                                             Icon(Icons.radio_button_checked, color: Colors.red),
                                                           ],
                                                         ),
                                                         const SizedBox(width: 12),
                                                         Expanded(
                                                           child: Column(
                                                             crossAxisAlignment: CrossAxisAlignment.start,
                                                             children: [
                                                               Row(
                                                                 children: [
                                                                   // Source Location Name
                                                                   Expanded(
                                                                     child: Text(
                                                                       order.sourceLocationName.toString(),
                                                                       style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                                                       maxLines: 2,
                                                                       overflow: TextOverflow.ellipsis,
                                                                     ),
                                                                   ),
                                                                   const SizedBox(width: 8),
                                                                   Container(
                                                                     decoration: BoxDecoration(
                                                                       borderRadius: BorderRadius.circular(10),
                                                                       border: Border.all(color: AppThemeData.warning300, width: 1),
                                                                       color: AppThemeData.warning50,
                                                                     ),
                                                                     padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                                                     child: Text(
                                                                       order.status.toString(),
                                                                       style: AppThemeData.boldTextStyle(fontSize: 14, color: AppThemeData.warning500),
                                                                       overflow: TextOverflow.ellipsis,
                                                                     ),
                                                                   ),
                                                                 ],
                                                               ),
                                                               SizedBox(height: 15),
                                                               DottedBorder(
                                                                 options: CustomPathDottedBorderOptions(
                                                                   color: Colors.grey.shade400,
                                                                   strokeWidth: 2,
                                                                   dashPattern: [4, 4],
                                                                   customPath:
                                                                       (size) =>
                                                                           Path()
                                                                             ..moveTo(0, size.height / 2) // start from left center
                                                                             ..lineTo(size.width, size.height / 2), // draw to right center
                                                                 ),
                                                                 child: const SizedBox(width: 295, height: 3),
                                                               ),
                                                               SizedBox(height: 15),
                                                               Text(
                                                                 order.destinationLocationName.toString(),
                                                                 style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                                               ),
                                                             ],
                                                           ),
                                                         ),
                                                       ],
                                                     ),
                                                     if (Constant.isEnableOTPTripStart == true)
                                                       Row(
                                                         //mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                         crossAxisAlignment: CrossAxisAlignment.center,
                                                         children: [
                                                           Text("Otp :".tr, style: AppThemeData.mediumTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark800 : AppThemeData.grey800)),
                                                           SizedBox(width: 5),
                                                           Text(order.otpCode ?? '', style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
                                                         ],
                                                       ),
                                                     if (order.status == Constant.orderInTransit && order.paymentStatus == false) SizedBox(height: 14),
                                                     order.status == Constant.orderInTransit && order.paymentStatus == false
                                                         ? RoundedButtonFill(
                                                           title: "Pay Now".tr,
                                                           onPress: () async {
                                                             controller.selectedPaymentMethod.value = order.paymentMethod.toString();
                                                             controller.calculateTotalAmount(order);
                                                             Get.bottomSheet(paymentBottomSheet(context, controller, isDark), isScrollControlled: true, backgroundColor: Colors.transparent);
                                                           },
                                                           color: AppThemeData.primary300,
                                                           textColor: AppThemeData.grey900,
                                                         )
                                                         : SizedBox(),
                                                   ],
                                                 ),
                                               ),
                                             );
                                           },
                                         ),
                                       ),
                                     );
                                   }).toList(),
                             ),
                      ),
          ),
        );
      },
    );
  }

  Widget paymentBottomSheet(BuildContext context, MyCabBookingController controller, bool isDark) {
    return DraggableScrollableSheet(
      initialChildSize: 0.70,
      // Start height
      minChildSize: 0.30,
      // Minimum height
      maxChildSize: 0.8,
      // Maximum height
      expand: false,
      //Prevents full-screen takeover
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(color: isDark ? AppThemeData.grey500 : Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Select Payment Method".tr, style: AppThemeData.mediumTextStyle(fontSize: 18, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
                  GestureDetector(
                    onTap: () {
                      Get.back();
                    },
                    child: Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  controller: scrollController,
                  children: [
                    Text("Preferred Payment".tr, textAlign: TextAlign.start, style: AppThemeData.boldTextStyle(fontSize: 15, color: isDark ? AppThemeData.greyDark500 : AppThemeData.grey500)),
                    const SizedBox(height: 10),
                    if (controller.walletSettingModel.value.isEnabled == true || controller.cashOnDeliverySettingModel.value.isEnabled == true)
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                          border: Border.all(color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            children: [
                              Visibility(
                                visible: controller.walletSettingModel.value.isEnabled == true,
                                child: cardDecoration(controller, PaymentGateway.wallet, isDark, "assets/images/ic_wallet.png"),
                              ),
                              Visibility(
                                visible: controller.cashOnDeliverySettingModel.value.isEnabled == true,
                                child: cardDecoration(controller, PaymentGateway.cod, isDark, "assets/images/ic_cash.png"),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (controller.walletSettingModel.value.isEnabled == true || controller.cashOnDeliverySettingModel.value.isEnabled == true)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 10),
                          Text(
                            "Other Payment Options".tr,
                            textAlign: TextAlign.start,
                            style: AppThemeData.boldTextStyle(fontSize: 15, color: isDark ? AppThemeData.greyDark500 : AppThemeData.grey500),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                        border: Border.all(color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            Visibility(visible: controller.stripeModel.value.isEnabled == true, child: cardDecoration(controller, PaymentGateway.stripe, isDark, "assets/images/stripe.png")),
                            Visibility(visible: controller.payPalModel.value.isEnabled == true, child: cardDecoration(controller, PaymentGateway.paypal, isDark, "assets/images/paypal.png")),
                            Visibility(visible: controller.payStackModel.value.isEnable == true, child: cardDecoration(controller, PaymentGateway.payStack, isDark, "assets/images/paystack.png")),
                            Visibility(
                              visible: controller.mercadoPagoModel.value.isEnabled == true,
                              child: cardDecoration(controller, PaymentGateway.mercadoPago, isDark, "assets/images/mercado-pago.png"),
                            ),
                            Visibility(
                              visible: controller.flutterWaveModel.value.isEnable == true,
                              child: cardDecoration(controller, PaymentGateway.flutterWave, isDark, "assets/images/flutterwave_logo.png"),
                            ),
                            Visibility(visible: controller.payFastModel.value.isEnable == true, child: cardDecoration(controller, PaymentGateway.payFast, isDark, "assets/images/payfast.png")),
                            Visibility(visible: controller.razorPayModel.value.isEnabled == true, child: cardDecoration(controller, PaymentGateway.razorpay, isDark, "assets/images/razorpay.png")),
                            Visibility(visible: controller.midTransModel.value.enable == true, child: cardDecoration(controller, PaymentGateway.midTrans, isDark, "assets/images/midtrans.png")),
                            Visibility(
                              visible: controller.orangeMoneyModel.value.enable == true,
                              child: cardDecoration(controller, PaymentGateway.orangeMoney, isDark, "assets/images/orange_money.png"),
                            ),
                            Visibility(visible: controller.xenditModel.value.enable == true, child: cardDecoration(controller, PaymentGateway.xendit, isDark, "assets/images/xendit.png")),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                  ],
                ),
              ),
              RoundedButtonFill(
                title: "Continue".tr,
                color: AppThemeData.primary300,
                textColor: AppThemeData.grey900,
                onPress: () async {
                  if (controller.selectedPaymentMethod.value.isEmpty) {
                    ShowToastDialog.showToast("Please select a payment method".tr);
                  } else {
                    if (controller.selectedPaymentMethod.value == PaymentGateway.stripe.name) {
                      controller.stripeMakePayment(amount: controller.totalAmount.value.toString());
                    } else if (controller.selectedPaymentMethod.value == PaymentGateway.paypal.name) {
                      controller.paypalPaymentSheet(controller.totalAmount.value.toString(), context);
                    } else if (controller.selectedPaymentMethod.value == PaymentGateway.payStack.name) {
                      controller.payStackPayment(controller.totalAmount.value.toString());
                    } else if (controller.selectedPaymentMethod.value == PaymentGateway.mercadoPago.name) {
                      controller.mercadoPagoMakePayment(context: context, amount: controller.totalAmount.value.toString());
                    } else if (controller.selectedPaymentMethod.value == PaymentGateway.flutterWave.name) {
                      controller.flutterWaveInitiatePayment(context: context, amount: controller.totalAmount.value.toString());
                    } else if (controller.selectedPaymentMethod.value == PaymentGateway.payFast.name) {
                      controller.payFastPayment(context: context, amount: controller.totalAmount.value.toString());
                    } else if (controller.selectedPaymentMethod.value == PaymentGateway.cod.name) {
                      controller.completeOrder();
                    } else if (controller.selectedPaymentMethod.value == PaymentGateway.wallet.name) {
                      if (Constant.userModel!.walletAmount == null || Constant.userModel!.walletAmount! < controller.totalAmount.value) {
                        ShowToastDialog.showToast("You do not have sufficient wallet balance".tr);
                      } else {
                        controller.completeOrder();
                      }
                    } else if (controller.selectedPaymentMethod.value == PaymentGateway.midTrans.name) {
                      controller.midtransMakePayment(context: context, amount: controller.totalAmount.value.toString());
                    } else if (controller.selectedPaymentMethod.value == PaymentGateway.orangeMoney.name) {
                      controller.orangeMakePayment(context: context, amount: controller.totalAmount.value.toString());
                    } else if (controller.selectedPaymentMethod.value == PaymentGateway.xendit.name) {
                      controller.xenditPayment(context, controller.totalAmount.value.toString());
                    } else if (controller.selectedPaymentMethod.value == PaymentGateway.razorpay.name) {
                      RazorPayController().createOrderRazorPay(amount: double.parse(controller.totalAmount.value.toString()), razorpayModel: controller.razorPayModel.value).then((value) {
                        if (value == null) {
                          Get.back();
                          ShowToastDialog.showToast("Something went wrong, please contact admin.".tr);
                        } else {
                          CreateRazorPayOrderModel result = value;
                          controller.openCheckout(amount: controller.totalAmount.value.toString(), orderId: result.id);
                        }
                      });
                    } else {
                      ShowToastDialog.showToast("Please select payment method".tr);
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Obx cardDecoration(MyCabBookingController controller, PaymentGateway value, isDark, String image) {
    return Obx(
      () => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(
          children: [
            InkWell(
              onTap: () {
                controller.selectedPaymentMethod.value = value.name;
              },
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: ShapeDecoration(shape: RoundedRectangleBorder(side: const BorderSide(width: 1, color: Color(0xFFE5E7EB)), borderRadius: BorderRadius.circular(8))),
                    child: Padding(padding: EdgeInsets.all(value.name == "payFast" ? 0 : 8.0), child: Image.asset(image)),
                  ),
                  const SizedBox(width: 10),
                  value.name == "wallet"
                      ? Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              value.name.capitalizeString(),
                              textAlign: TextAlign.start,
                              style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900),
                            ),
                            Text(
                              Constant.amountShow(amount: Constant.userModel!.walletAmount == null ? '0.0' : Constant.userModel!.walletAmount.toString()),
                              textAlign: TextAlign.start,
                              style: AppThemeData.semiBoldTextStyle(fontSize: 14, color: isDark ? AppThemeData.primary300 : AppThemeData.primary300),
                            ),
                          ],
                        ),
                      )
                      : Expanded(
                        child: Text(
                          value.name.capitalizeString(),
                          textAlign: TextAlign.start,
                          style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900),
                        ),
                      ),
                  const Expanded(child: SizedBox()),
                  Radio(
                    value: value.name,
                    groupValue: controller.selectedPaymentMethod.value,
                    activeColor: isDark ? AppThemeData.primary300 : AppThemeData.primary300,
                    onChanged: (value) {
                      controller.selectedPaymentMethod.value = value.toString();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
