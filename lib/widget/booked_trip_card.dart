import 'package:customer/constant/constant.dart';
import 'package:customer/models/driver_trip_model.dart';
import 'package:customer/models/user_model.dart';
import 'package:customer/screen_ui/multi_vendor_service/chat_screens/chat_screen.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/utils/driver_trip_state.dart';
import 'package:customer/utils/network_image_widget.dart';
import 'package:customer/widget/my_separator.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

/// A full vehicle this customer has booked off a driver-posted trip.
///
/// The card the Trips section used to draw in its own *My Bookings* tab. It
/// lives in `widget/` now because Ride History draws it instead: the client
/// asked for one booking list for every kind of trip, so the card had to move
/// somewhere both screens could reach rather than be copied into the second.
///
/// Everything on it is unchanged - the same trip line, the same driver block
/// with the number printed under the name, and the same two 42 px Call and
/// Chat buttons, hidden once the trip is cancelled or expired.
class BookedTripCard extends StatelessWidget {
  const BookedTripCard({super.key, required this.trip, required this.driver, required this.isDark});

  final DriverTripModel trip;

  /// The posting driver's profile, once the live read lands. Null until then;
  /// the card falls back to what the trip document itself carries.
  final UserModel? driver;

  final bool isDark;

  static final DateFormat _tripFormat = DateFormat('dd MMM yyyy, hh:mm a');

  @override
  Widget build(BuildContext context) {
    final String status = trip.effectiveStatusAt(DateTime.now());
    final String phone = '${driver?.countryCode ?? ''}${driver?.phoneNumber ?? ''}'.trim();
    final bool ended = DriverTripStatus.isFinished(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppThemeData.greyDark50 : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  trip.tripDateTime == null ? '' : _tripFormat.format(trip.tripDateTime!.toDate()),
                  style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                ),
              ),
              const SizedBox(width: 8),
              _statusChip(status),
            ],
          ),
          const SizedBox(height: 6),
          // Ride History mixes two kinds of booking in one list, so each row has
          // to say which it is. On its own screen the heading did that job.
          Text(
            "Full Vehicle Trip".tr,
            style: AppThemeData.regularTextStyle(fontSize: 12, color: isDark ? AppThemeData.grey400 : AppThemeData.grey500),
          ),
          const SizedBox(height: 10),
          _locationRow(Icons.stop_circle_outlined, Colors.green, trip.fromAddress ?? ''),
          const SizedBox(height: 6),
          _locationRow(Icons.radio_button_checked, Colors.red, trip.toAddress ?? ''),
          if ((trip.note ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                trip.note!,
                style: AppThemeData.mediumTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark700 : AppThemeData.grey700),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: MySeparator(color: isDark ? AppThemeData.grey700 : AppThemeData.grey200),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  "Full Vehicle Price".tr,
                  style: AppThemeData.regularTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark700 : AppThemeData.grey600),
                ),
              ),
              Text(
                Constant.amountShow(amount: (trip.fullVehiclePrice ?? 0).toString()),
                style: AppThemeData.boldTextStyle(fontSize: 18, color: AppThemeData.primary300),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "Your driver".tr,
            style: AppThemeData.regularTextStyle(fontSize: 12, color: isDark ? AppThemeData.grey400 : AppThemeData.grey500),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: NetworkImageWidget(imageUrl: trip.driverPhoto ?? '', height: 44, width: 44, borderRadius: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      (trip.driverName ?? '').trim().isEmpty ? "Driver".tr : trip.driverName!.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppThemeData.semiBoldTextStyle(fontSize: 15, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      phone.isEmpty ? "Phone number not shared".tr : phone,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppThemeData.regularTextStyle(
                        fontSize: 14,
                        color: phone.isEmpty ? AppThemeData.grey500 : (isDark ? AppThemeData.greyDark700 : AppThemeData.grey700),
                      ),
                    ),
                  ],
                ),
              ),
              // A cancelled or expired trip keeps the driver on the card as
              // history, but there is nothing left to arrange with them.
              if (!ended) ...<Widget>[
                const SizedBox(width: 8),
                _contactButton(
                  icon: Icons.call_outlined,
                  tooltip: "Call".tr,
                  enabled: phone.isNotEmpty,
                  onTap: () => Constant.makePhoneCall(phone),
                ),
                const SizedBox(width: 8),
                _contactButton(
                  icon: Icons.chat_bubble_outline,
                  tooltip: "Chat".tr,
                  enabled: (trip.driverId ?? '').isNotEmpty,
                  onTap: () => openChat(trip, driver),
                ),
              ],
            ],
          ),
          if ((trip.vehicleType ?? '').isNotEmpty || trip.vehicleDescription.isNotEmpty || (trip.vehiclePlate ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if ((trip.vehicleType ?? '').isNotEmpty) _chip(trip.vehicleType!),
                  if (trip.vehicleDescription.isNotEmpty) _chip(trip.vehicleDescription),
                  if ((trip.vehiclePlate ?? '').isNotEmpty) _chip(trip.vehiclePlate!.toUpperCase()),
                  if (trip.airConditioning != null) _chip(trip.airConditioning! ? "AC".tr : "Non-AC".tr),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Opens the app's existing chat on this trip.
  ///
  /// Keyed by the trip id, which is what the driver app also passes, so both
  /// sides read and write the same `chat/{id}/thread` and the conversation
  /// appears in the ordinary inbox on both devices.
  static Future<void> openChat(DriverTripModel trip, UserModel? driver) async {
    final String driverId = (trip.driverId ?? '').trim();
    if (driverId.isEmpty) return;

    ShowToastDialog.showLoader("Please wait".tr);
    final UserModel? me = await _currentUser();
    ShowToastDialog.closeLoader();
    if (me == null) {
      ShowToastDialog.showToast("Something went wrong. Please try again.".tr);
      return;
    }

    Get.to(const ChatScreen(), arguments: <String, dynamic>{
      "senderName": me.fullName(),
      "senderId": me.id,
      "senderProfileUrl": me.profilePictureURL ?? '',
      "receivedName": (driver?.fullName() ?? trip.driverName ?? '').trim(),
      "receivedId": driverId,
      "receivedProfileUrl": driver?.profilePictureURL ?? trip.driverPhoto ?? '',
      "orderId": trip.id,
      // The trip document carries the driver's token, so the chat can notify
      // them even before the profile read lands.
      "token": driver?.fcmToken ?? trip.driverFcmToken ?? '',
      "chatType": Constant.userRoleDriver,
      "chatSubtitle": "${'Trip'.tr} · ${trip.fromAddress ?? ''} → ${trip.toAddress ?? ''}",
    });
  }

  /// The signed-in customer, for the chat header and the sender id.
  ///
  /// `Constant.userModel` is only populated by a profile write, so it can still
  /// be null on a session that has only ever read. Falling back to the profile
  /// read means the Chat button cannot silently do nothing.
  static Future<UserModel?> _currentUser() async {
    final UserModel? cached = Constant.userModel;
    if (cached != null && (cached.id ?? '').isNotEmpty) return cached;
    final String uid = FireStoreUtils.getCurrentUid();
    if (uid.isEmpty) return null;
    return FireStoreUtils.getUserProfile(uid);
  }

  Widget _statusChip(String status) {
    Color color;
    String label;
    switch (status) {
      case DriverTripStatus.booked:
        color = AppThemeData.primary300;
        label = "Booked".tr;
        break;
      case DriverTripStatus.cancelled:
        color = AppThemeData.danger300;
        label = "Cancelled by driver".tr;
        break;
      case DriverTripStatus.expired:
        color = isDark ? AppThemeData.grey400 : AppThemeData.grey500;
        label = "Expired".tr;
        break;
      default:
        color = AppThemeData.success400;
        label = "Active".tr;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: color.withValues(alpha: 0.15)),
      child: Text(label, style: AppThemeData.semiBoldTextStyle(fontSize: 12, color: color)),
    );
  }

  Widget _contactButton({required IconData icon, required String tooltip, required bool enabled, required VoidCallback onTap}) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: enabled ? onTap : null,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: enabled ? AppThemeData.primary300 : (isDark ? AppThemeData.grey700 : AppThemeData.grey200)),
          ),
          child: Icon(icon, size: 20, color: enabled ? AppThemeData.primary300 : (isDark ? AppThemeData.grey600 : AppThemeData.grey400)),
        ),
      ),
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: isDark ? AppThemeData.grey700 : AppThemeData.grey100),
      child: Text(
        label,
        style: AppThemeData.mediumTextStyle(fontSize: 12, color: isDark ? AppThemeData.greyDark800 : AppThemeData.grey800),
      ),
    );
  }

  Widget _locationRow(IconData icon, Color color, String label) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: AppThemeData.mediumTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark800 : AppThemeData.grey800),
          ),
        ),
      ],
    );
  }
}
