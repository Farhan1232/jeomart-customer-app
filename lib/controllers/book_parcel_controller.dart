import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:customer/models/vendor_model.dart';
import 'package:customer/widget/geoflutterfire/src/geoflutterfire.dart';
import 'package:dropdown_textfield/dropdown_textfield.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:customer/utils/safe_geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as latlong;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../constant/constant.dart';
import '../models/parcel_category.dart';
import '../models/parcel_order_model.dart';
import '../models/parcel_weight_model.dart';
import '../models/user_model.dart';
import '../screen_ui/parcel_service/parcel_order_confirmation.dart';
import '../service/fire_store_utils.dart';
import '../themes/show_toast_dialog.dart';

class BookParcelController extends GetxController {
  // Sender details
  final Rx<TextEditingController> senderLocationController = TextEditingController().obs;
  final Rx<TextEditingController> senderNameController = TextEditingController().obs;
  final Rx<TextEditingController> senderMobileController = TextEditingController().obs;
  final Rx<SingleValueDropDownController> senderWeightController = SingleValueDropDownController().obs;
  final Rx<TextEditingController> senderNoteController = TextEditingController().obs;
  final Rx<TextEditingController> senderCountryCodeController = TextEditingController(text: Constant.defaultCountryCode).obs;
  final Rx<TextEditingController> senderCountryISOCodeController = TextEditingController(text: Constant.defaultCountryCode).obs;

  // Receiver details
  final Rx<TextEditingController> receiverLocationController = TextEditingController().obs;
  final Rx<TextEditingController> receiverNameController = TextEditingController().obs;
  final Rx<TextEditingController> receiverMobileController = TextEditingController().obs;
  final Rx<TextEditingController> receiverNoteController = TextEditingController().obs;
  final Rx<TextEditingController> receiverCountryCodeController = TextEditingController(text: Constant.defaultCountryCode).obs;
  final Rx<TextEditingController> receiverISOCountryCodeController = TextEditingController(text: Constant.defaultCountryCode).obs;

  // Delivery type
  final RxString selectedDeliveryType = 'now'.obs;

  // Scheduled delivery fields
  final Rx<TextEditingController> scheduledDateController = TextEditingController().obs;
  final Rx<TextEditingController> scheduledTimeController = TextEditingController().obs;
  final RxString scheduledDate = ''.obs;
  final RxString scheduledTime = ''.obs;

  // Parcel weight list
  final RxList<ParcelWeightModel> parcelWeight = <ParcelWeightModel>[].obs;

  final RxList<XFile> images = <XFile>[].obs;
  final ImagePicker _picker = ImagePicker();

  Rx<UserLocation?> senderLocation = Rx<UserLocation?>(null);
  Rx<UserLocation?> receiverLocation = Rx<UserLocation?>(null);

  ParcelWeightModel? selectedWeight;
  ParcelCategory? selectedCategory;

  // UI observables
  RxBool isScheduled = false.obs;
  RxDouble distance = 0.0.obs;
  RxDouble duration = 0.0.obs;
  RxDouble subTotal = 0.0.obs;

  @override
  void onInit() {
    super.onInit();
    setArguments();
    getParcelWeight();
    setCurrentLocationForSenderAndReceiver();
  }

  void setArguments() {
    if (Get.arguments != null && Get.arguments['parcelCategory'] != null) {
      selectedCategory = Get.arguments['parcelCategory'];
    }
  }

  Future<void> getParcelWeight() async {
    parcelWeight.value = await FireStoreUtils.getParcelWeight();
  }

  Future<void> pickScheduledDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
    if (picked != null) {
      final formattedDate = "${picked.day}/${picked.month}/${picked.year}";
      scheduledDate.value = formattedDate;
      scheduledDateController.value.text = formattedDate;
    }
  }

  Future<void> pickScheduledTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (picked != null) {
      final formattedTime = picked.format(context);
      scheduledTime.value = formattedTime;
      scheduledTimeController.value.text = formattedTime;
    }
  }

  void onCameraClick(BuildContext context) {
    final action = CupertinoActionSheet(
      message: Text('Add your parcel image.'.tr, style: const TextStyle(fontSize: 15.0)),
      actions: <Widget>[
        CupertinoActionSheetAction(
          child: Text('Choose image from gallery'.tr),
          onPressed: () async {
            Navigator.pop(context);
            final imageList = await _picker.pickMultiImage();
            if (imageList.isNotEmpty) {
              images.addAll(imageList);
            }
          },
        ),
        CupertinoActionSheetAction(
          child: Text('Take a picture'.tr),
          onPressed: () async {
            Navigator.pop(context);
            final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
            if (photo != null) {
              images.add(photo);
            }
          },
        ),
      ],
      cancelButton: CupertinoActionSheetAction(child: Text('Cancel'.tr), onPressed: () => Navigator.pop(context)),
    );
    showCupertinoModalPopup(context: context, builder: (context) => action);
  }

  Future<void> setCurrentLocationForSenderAndReceiver() async {
    try {
      await Geolocator.requestPermission();
      final position = await Geolocator.getCurrentPosition();
      final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      final place = placemarks.first;
      final address = "${place.name}, ${place.subLocality}, ${place.locality}, ${place.administrativeArea}, ${place.postalCode}, ${place.country}";

      final userLocation = UserLocation(latitude: position.latitude, longitude: position.longitude);
      senderLocation.value = userLocation;
      senderLocationController.value.text = address;
    } catch (e) {
      debugPrint("Failed to fetch current location: $e");
    }
  }

  bool validateFields() {
    if (senderNameController.value.text.isEmpty) {
      ShowToastDialog.showToast("Please enter sender name".tr);
      return false;
    } else if (senderMobileController.value.text.isEmpty) {
      ShowToastDialog.showToast("Please enter sender mobile".tr);
      return false;
    } else if (senderLocationController.value.text.isEmpty) {
      ShowToastDialog.showToast("Please enter sender address".tr);
      return false;
    } else if (receiverNameController.value.text.isEmpty) {
      ShowToastDialog.showToast("Please enter receiver name".tr);
      return false;
    } else if (receiverMobileController.value.text.isEmpty) {
      ShowToastDialog.showToast("Please enter receiver mobile".tr);
      return false;
    } else if (receiverLocationController.value.text.isEmpty) {
      ShowToastDialog.showToast("Please enter receiver address".tr);
      return false;
    } else if (isScheduled.value) {
      if (scheduledDate.value.isEmpty) {
        ShowToastDialog.showToast("Please select scheduled date".tr);
        return false;
      } else if (scheduledTime.value.isEmpty) {
        ShowToastDialog.showToast("Please select scheduled time".tr);
        return false;
      }
    }

    if (selectedWeight == null) {
      ShowToastDialog.showToast("Please select parcel weight".tr);
      return false;
    } else if (senderLocation.value == null || receiverLocation.value == null) {
      ShowToastDialog.showToast("Please select both sender and receiver locations".tr);
      return false;
    }
    return true;
  }

  Future<void> bookNow() async {
    if (!validateFields()) return;

    try {
      distance.value = 0.0;

      if (Constant.selectedMapType == 'osm') {
        print("Fetching route using OSM");
        print("Sender Location: ${senderLocation.value?.latitude}, ${senderLocation.value?.longitude}");
        print("Receiver Location: ${receiverLocation.value?.latitude}, ${receiverLocation.value?.longitude}");
        await fetchRouteWithWaypoints([
          latlong.LatLng(senderLocation.value?.latitude ?? 0.0, senderLocation.value?.longitude ?? 0.0),
          latlong.LatLng(receiverLocation.value?.latitude ?? 0.0, receiverLocation.value?.longitude ?? 0.0),
        ]);
      } else {
        await fetchGoogleRouteWithWaypoints();
      }

      if (distance.value < 0.5) {
        ShowToastDialog.showToast("Sender's location to receiver's location should be more than 1 km.".tr);
        return;
      }

      subTotal.value = (distance.value * double.parse(selectedWeight!.deliveryCharge.toString()));
      goToCart();
    } catch (e) {
      ShowToastDialog.showToast("Something went wrong while booking.".tr);
      debugPrint("bookNow error: $e");
    }
  }

  void goToCart() {
    DateTime senderPickup = isScheduled.value ? parseScheduledDateTime(scheduledDate.value, scheduledTime.value) : DateTime.now();

    print("Sender Pickup: $distance");
    ParcelOrderModel order = ParcelOrderModel(
      id: Constant.getUuid(),
      subTotal: subTotal.value.toString(),
      parcelType: selectedCategory?.title ?? '',
      parcelCategoryID: selectedCategory?.id ?? '',
      note: senderNoteController.value.text,
      receiverNote: receiverNoteController.value.text,
      distance: distance.value.toStringAsFixed(4),
      parcelWeight: selectedWeight?.title ?? '',
      parcelWeightCharge: selectedWeight?.deliveryCharge,
      sendToDriver: isScheduled.value == true ? false : true,
      senderPickupDateTime: Timestamp.fromDate(senderPickup),
      receiverPickupDateTime: Timestamp.fromDate(DateTime.now()),

      isSchedule: isScheduled.value,
      sourcePoint: G(
        geopoint: GeoPoint(senderLocation.value!.latitude ?? 0.0, senderLocation.value!.longitude ?? 0.0),
        geohash: Geoflutterfire().point(latitude: senderLocation.value!.latitude ?? 0.0, longitude: senderLocation.value!.longitude ?? 0.0).hash,
      ),
      destinationPoint: G(
        geopoint: GeoPoint(receiverLocation.value!.latitude ?? 0.0, receiverLocation.value!.longitude ?? 0.0),
        geohash: Geoflutterfire().point(latitude: receiverLocation.value!.latitude ?? 0.0, longitude: receiverLocation.value!.longitude ?? 0.0).hash,
      ),
      sender: LocationInformation(
        address: senderLocationController.value.text,
        name: senderNameController.value.text,
        phone: "(${senderCountryCodeController.value.text}) ${senderMobileController.value.text}",
      ),
      receiver: LocationInformation(
        address: receiverLocationController.value.text,
        name: receiverNameController.value.text,
        phone: "(${receiverCountryCodeController.value.text}) ${receiverMobileController.value.text}",
      ),
      receiverLatLong: receiverLocation.value,
      senderLatLong: senderLocation.value,
      sectionId: Constant.sectionConstantModel?.id ?? '',
      taxSetting: Constant.orderProductTaxList,
      platformFee: Constant.platformFeeModel?.fee ?? '0.0',
      platformTax: Constant.platformTaxList,
    );

    debugPrint("Order Distance: ${distance.value}");
    debugPrint("Subtotal: ${subTotal.value}");
    debugPrint("Order JSON: ${order.toJson()}");

    Get.to(() => ParcelOrderConfirmationScreen(), arguments: {'parcelOrder': order, 'images': images});
  }

  DateTime parseScheduledDateTime(String dateStr, String timeStr) {
    try {
      final dateParts = dateStr.split('/');
      final day = int.parse(dateParts[0]);
      final month = int.parse(dateParts[1]);
      final year = int.parse(dateParts[2]);

      final time = TimeOfDay(hour: int.parse(timeStr.split(':')[0]), minute: int.parse(timeStr.split(':')[1].split(' ')[0]));
      final isPM = timeStr.toLowerCase().contains('pm');
      final hour24 = isPM && time.hour < 12 ? time.hour + 12 : time.hour;

      return DateTime(year, month, day, hour24, time.minute);
    } catch (e) {
      debugPrint("Failed to parse scheduled date/time: $e");
      return DateTime.now();
    }
  }

  Future<void> fetchGoogleRouteWithWaypoints() async {
    final origin = '${senderLocation.value!.latitude},${senderLocation.value!.longitude}';
    final destination = '${receiverLocation.value!.latitude},${receiverLocation.value!.longitude}';
    final url = Uri.parse('https://maps.googleapis.com/maps/api/directions/json?origin=$origin&destination=$destination&mode=driving&key=${Constant.mapAPIKey}');

    try {
      final response = await http.get(url).timeout(Constant.mapRequestTimeout);
      final data = json.decode(response.body);
      if (data['status'] == 'OK') {
        final route = data['routes'][0];
        final legs = route['legs'] as List;
        num totalDistance = 0;
        num totalDuration = 0;
        for (var leg in legs) {
          totalDistance += leg['distance']['value'];
          totalDuration += leg['duration']['value'];
        }
        if (Constant.distanceType.toLowerCase() == "KM".toLowerCase()) {
          distance.value = totalDistance / 1000.0;
        } else {
          distance.value = totalDistance / 1609.34;
        }
        duration.value = (totalDuration / 60).round().toDouble();
      } else {
        debugPrint('Google Directions API Error: ${data['status']}');
      }
    } catch (e) {
      debugPrint("Google route fetch error: $e");
    }
  }

  Future<void> fetchRouteWithWaypoints(List<latlong.LatLng> points) async {
    final coordinates = points.map((p) => '${p.longitude},${p.latitude}').join(';');
    final url = Uri.parse('https://router.project-osrm.org/route/v1/driving/$coordinates?overview=full&geometries=geojson');

    try {
      final response = await http.get(url).timeout(Constant.mapRequestTimeout);
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final dist = decoded['routes'][0]['distance'];
        final dur = decoded['routes'][0]['duration'];

        if (Constant.distanceType.toLowerCase() == "KM".toLowerCase()) {
          distance.value = dist / 1000.00;
        } else {
          distance.value = dist / 1609.34;
        }
        duration.value = (dur / 60).round().toDouble();
      } else {
        debugPrint("Failed to get route: ${response.body}");
      }
    } catch (e) {
      debugPrint("Route fetch error: $e");
    }
  }
}
