import 'package:customer/constant/constant.dart';
import 'package:customer/models/language_model.dart';
import '../service/fire_store_utils.dart';
import 'package:customer/utils/preferences.dart';
import 'package:get/get.dart';

import '../constant/collection_name.dart';

class ChangeLanguageController extends GetxController {
  Rx<LanguageModel> selectedLanguage = LanguageModel().obs;
  RxList<LanguageModel> languageList = <LanguageModel>[].obs;
  RxBool isLoading = true.obs;

  @override
  void onInit() {
    // TODO: implement onInit
    getLanguage();

    super.onInit();
  }

  Future<void> getLanguage() async {
    await FireStoreUtils.fireStore.collection(CollectionName.settings).doc("languages").get().then((event) {
      if (event.exists) {
        List languageListTemp = event.data()!["list"];
        for (var element in languageListTemp) {
          LanguageModel languageModel = LanguageModel.fromJson(element);
          if (languageModel.isActive == true) {
            languageList.add(languageModel);
          }
        }

        if (Preferences.getString(Preferences.languageCodeKey).toString().isNotEmpty) {
          LanguageModel pref = Constant.getLanguage();
          for (var element in languageList) {
            if (element.slug == pref.slug) {
              selectedLanguage.value = element;
            }
          }
        }
      }
    });

    isLoading.value = false;
  }
}
