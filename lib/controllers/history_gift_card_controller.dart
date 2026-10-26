import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/models/gift_cards_order_model.dart';
import 'package:share_plus/share_plus.dart';
import '../service/fire_store_utils.dart';
import 'package:get/get.dart';

class HistoryGiftCardController extends GetxController {
  RxList<GiftCardsOrderModel> giftCardsOrderList = <GiftCardsOrderModel>[].obs;
  RxBool isLoading = true.obs;

  @override
  void onInit() {
    getData();
    super.onInit();
  }

  Future<void> getData() async {
    await FireStoreUtils.getGiftHistory().then((value) {
      giftCardsOrderList.value = value;
    });
    isLoading.value = false;
  }

  void updateList(int index) {
    GiftCardsOrderModel giftCardsOrderModel = giftCardsOrderList[index];
    giftCardsOrderModel.isPasswordShow = giftCardsOrderModel.isPasswordShow == true ? false : true;

    giftCardsOrderList.removeAt(index);
    giftCardsOrderList.insert(index, giftCardsOrderModel);
  }

  Future<void> share(String giftCode, String giftPin, String msg, String amount, Timestamp date) async {
    await Share.share(
      "${'Gift Code :'.tr} $giftCode\n${'Gift Pin :'.tr} $giftPin\n${'Price :'.tr} ${Constant.amountShow(amount: amount)}\n${'Expire Date :'.tr} ${date.toDate()}\n\n${'Message'.tr} : $msg",
    );
  }
}
