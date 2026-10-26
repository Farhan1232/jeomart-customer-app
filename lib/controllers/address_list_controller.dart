import 'package:customer/models/user_model.dart';
import 'package:get/get.dart';

import '../constant/constant.dart';
import '../service/fire_store_utils.dart';

class AddressListController extends GetxController {
  Rx<UserModel> userModel = UserModel().obs;

  RxList<ShippingAddress> shippingAddressList = <ShippingAddress>[].obs;
  RxBool isLoading = true.obs;

  @override
  void onInit() {
    // TODO: implement onInit
    getUser();
    super.onInit();
  }

  Future<void> getUser() async {
    await FireStoreUtils.getUserProfile(FireStoreUtils.getCurrentUid()).then((value) {
      if (value != null) {
        userModel.value = value;
        if (userModel.value.shippingAddress != null) {
          shippingAddressList.value = userModel.value.shippingAddress!;
        }
      }
    });
    isLoading.value = false;
  }

  Future<void> deleteAddress(int index) async {
    if (shippingAddressList.isNotEmpty && index < shippingAddressList.length) {
      shippingAddressList.removeAt(index);
      userModel.value.shippingAddress = shippingAddressList;
      if (shippingAddressList.isNotEmpty) {
        Constant.selectedLocation = shippingAddressList.first;
      }
      await FireStoreUtils.updateUser(userModel.value);
      shippingAddressList.refresh();
    }
  }
}
