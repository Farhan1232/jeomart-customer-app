import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/on_demand_home_controller.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import '../models/favorite_ondemand_service_model.dart';
import '../models/provider_serivce_model.dart';
import '../service/fire_store_utils.dart';

class ViewAllPopularServiceController extends GetxController {
  RxList<ProviderServiceModel> providerList = <ProviderServiceModel>[].obs;
  RxList<ProviderServiceModel> allProviderList = <ProviderServiceModel>[].obs;
  RxBool isLoading = true.obs;
  Rx<OnDemandHomeController> onDemandHomeController = Get.find<OnDemandHomeController>().obs;

  final OnDemandHomeController onDemandController = Get.find<OnDemandHomeController>();

  Rx<TextEditingController> searchTextFiledController = TextEditingController().obs;

  RxList<FavouriteOndemandServiceModel> lstFav = <FavouriteOndemandServiceModel>[].obs;

  @override
  void onInit() {
    super.onInit();
    getData();
  }

  Future<void> getData() async {
    isLoading.value = true;

    await FireStoreUtils.getProviderFuture()
        .then((providerServiceList) {
          Set<String?> uniqueAuthorIds = providerServiceList.map((service) => service.author).toSet();
          List<String?> listOfUniqueProviders = uniqueAuthorIds.toList();

          List<ProviderServiceModel> filteredProviders = [];

          for (var provider in listOfUniqueProviders) {
            List<ProviderServiceModel> filteredList = providerServiceList.where((service) => service.author == provider).toList();

            filteredList.sort((a, b) => a.createdAt!.compareTo(b.createdAt!));

            for (int index = 0; index < filteredList.length; index++) {
              final service = filteredList[index];

              if (Constant.isSubscriptionModelApplied == true || Constant.sectionConstantModel?.adminCommision?.isEnabled == true) {
                if (service.subscriptionPlan?.itemLimit == "-1") {
                  filteredProviders.add(service);
                } else {
                  if (index < int.parse(service.subscriptionPlan?.itemLimit ?? '0')) {
                    filteredProviders.add(service);
                  }
                }
              } else {
                filteredProviders.add(service);
              }
            }
          }

          allProviderList.value = filteredProviders;
          providerList.value = filteredProviders;
          isLoading.value = false;
        })
        .catchError((e) {
          print("Provider error: $e");
          isLoading.value = false;
        });

    if (Constant.userModel != null) {
      await FireStoreUtils.getFavouritesServiceList(FireStoreUtils.getCurrentUid()).then((value) {
        lstFav.value = value;
      });
    }
    isLoading.value = false;
  }

  void getFilterData(String value) {
    if (value.isNotEmpty) {
      providerList.value = allProviderList.where((e) => e.title!.toLowerCase().contains(value.toLowerCase()) || e.title!.startsWith(value)).toList();
    } else {
      providerList.assignAll(allProviderList);
    }
  }
}
