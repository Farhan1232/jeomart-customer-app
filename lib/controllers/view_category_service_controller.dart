import 'package:customer/utils/parallel.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/on_demand_home_controller.dart';
import 'package:get/get.dart';
import '../models/provider_serivce_model.dart';
import '../service/fire_store_utils.dart';

class ViewCategoryServiceController extends GetxController {
  RxBool isLoading = true.obs;
  RxList<ProviderServiceModel> providerList = <ProviderServiceModel>[].obs;

  RxString categoryId = "".obs, categoryTitle = "".obs;
  Rx<OnDemandHomeController> onDemandHomeController = Get.find<OnDemandHomeController>().obs;

  @override
  void onInit() {
    super.onInit();

    final args = Get.arguments as Map<String, dynamic>;
    categoryId.value = args['categoryId'] ?? "";
    categoryTitle.value = args['categoryTitle'] ?? "";

    getData();
  }

  Future<void> getData() async {
    providerList.clear();
    isLoading.value = true;

    List<ProviderServiceModel> providerServiceList = await FireStoreUtils.getProviderFuture(categoryId: categoryId.value);

    List<String?> uniqueAuthId = providerServiceList.map((service) => service.author).toList();
    List<String?> uniqueServiceId = providerServiceList.map((service) => service.id).toList();

    List<ProviderServiceModel> filterByItemLimit = <ProviderServiceModel>[];
    List<String?> uniqueId = <String>[];

    if ((Constant.isSubscriptionModelApplied == true || Constant.sectionConstantModel!.adminCommision?.isEnabled == true)) {
      // `uniqueAuthId` is one entry per *service*, not per author - the name is
      // wishful. So a category whose 26 services belong to five providers used
      // to make 26 sequential queries where five distinct ones were needed, and
      // 21 of them asked for a list already in hand.
      //
      // Each distinct author is now fetched once, and they are fetched
      // together. The loop below is deliberately left exactly as it was,
      // including its repeats over duplicate authors, so the accumulation in
      // `filterByItemLimit` and the `uniqueId` guard behave identically - only
      // the network cost changes.
      final Map<String, List<ProviderServiceModel>> servicesByAuthor = <String, List<ProviderServiceModel>>{};
      await Parallel.map<String, void>(uniqueAuthId.whereType<String>().toSet().toList(), (String authorId) async {
        servicesByAuthor[authorId] = await FireStoreUtils.getAllProviderServiceByAuthorId(authorId);
        return null;
      });

      for (var authUser in uniqueAuthId) {
        List<ProviderServiceModel> listofAllServiceByAuth = servicesByAuthor[authUser!] ?? <ProviderServiceModel>[];

        for (int i = 0; i < listofAllServiceByAuth.length; i++) {
          if (listofAllServiceByAuth[i].subscriptionPlan?.itemLimit != null &&
              (i < int.parse(listofAllServiceByAuth[i].subscriptionPlan?.itemLimit ?? '0') || listofAllServiceByAuth[i].subscriptionPlan?.itemLimit == '-1')) {
            if (uniqueServiceId.contains(listofAllServiceByAuth[i].id)) {
              filterByItemLimit.add(listofAllServiceByAuth[i]);
            }
          }
        }

        for (var service in filterByItemLimit) {
          for (var unique in uniqueServiceId) {
            if (service.id == unique && !uniqueId.contains(service.id) && service.subscriptionTotalOrders != '0') {
              uniqueId.add(service.id);
              providerList.add(service);
            }
          }
        }
      }
    } else {
      providerList.addAll(providerServiceList);
    }

    isLoading.value = false;
  }
}
