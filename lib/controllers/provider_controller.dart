import 'package:customer/controllers/on_demand_home_controller.dart';
import 'package:get/get.dart';
import '../models/provider_serivce_model.dart';
import '../models/user_model.dart';
import '../service/fire_store_utils.dart';

class ProviderController extends GetxController {
  RxList<ProviderServiceModel> providerList = <ProviderServiceModel>[].obs;
  final Rxn<UserModel> userModel = Rxn<UserModel>();
  RxBool isLoading = true.obs;

  late final String providerId;
  Rx<OnDemandHomeController> onDemandHomeController = Get.put(OnDemandHomeController()).obs;

  @override
  void onInit() {
    super.onInit();

    //Get providerId from arguments
    providerId = Get.arguments['providerId'];

    getProvider();
    getAuthor();
  }

  void getProvider() async {
    FireStoreUtils.getProviderServiceByProviderId(providerId: providerId).then((catValue) {
      providerList.value = catValue;
    });

    isLoading.value = false;
  }

  Future<void> getAuthor() async {
    final user = await FireStoreUtils.getUserProfile(providerId);
    if (user != null) {
      userModel.value = user;
    }
  }
}
