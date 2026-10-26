import 'package:customer/models/coupon_model.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:get/get.dart';

class RentalCouponController extends GetxController{

  @override
  void onInit() {
    // TODO: implement onInit
    getData();
    super.onInit();
  }


  void getData(){
    getCouponCode();
  }
  RxBool isLoading = true.obs;
  RxList<CouponModel> cabCouponList = <CouponModel>[].obs;

  Future<void> getCouponCode() async {
    await FireStoreUtils.getRentalCoupon().then((value) {
      cabCouponList.value = value;
    });
    print("cabCouponList ${cabCouponList.length}");
    isLoading.value = false;
  }
}