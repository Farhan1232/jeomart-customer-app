import 'dart:async';
import 'package:customer/utils/firestore_cache.dart';
import 'package:customer/utils/user_cache.dart';
import 'package:customer/utils/bidding_settings.dart';
import 'package:customer/utils/driver_trip_settings.dart';
import 'package:customer/utils/wallet_ledger.dart';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:customer/constant/collection_name.dart';
import 'package:customer/firebase_options.dart';
import 'package:customer/models/brands_model.dart';
import 'package:customer/models/rental_order_model.dart';
import 'package:customer/models/rental_package_model.dart';
import 'package:customer/models/user_model.dart';
import 'package:customer/models/zone_model.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:customer/utils/safe_geocoding.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:video_compress/video_compress.dart';
import '../constant/constant.dart';
import '../models/attributes_model.dart';
import '../models/cab_order_model.dart';
import '../models/cashback_redeem_model.dart';
import '../models/category_model.dart';
import '../models/coupon_model.dart';
import '../models/currency_model.dart';
import '../models/favorite_ondemand_service_model.dart';
import '../models/gift_cards_model.dart';
import '../models/advertisement_model.dart';
import '../models/banner_model.dart';
import '../models/cashback_model.dart';
import '../models/conversation_model.dart';
import '../models/dine_in_booking_model.dart';
import '../models/email_template_model.dart';
import '../models/favourite_item_model.dart';
import '../models/favourite_model.dart';
import '../models/gift_cards_order_model.dart';
import '../models/inbox_model.dart';
import '../models/mail_setting.dart';
import '../models/notification_model.dart';
import '../models/on_boarding_model.dart';
import '../models/onprovider_order_model.dart';
import '../models/order_model.dart';
import '../models/parcel_category.dart';
import '../models/parcel_order_model.dart';
import '../models/parcel_weight_model.dart';
import '../models/payment_model/cod_setting_model.dart';
import '../models/payment_model/flutter_wave_model.dart';
import '../models/payment_model/mercado_pago_model.dart';
import '../models/payment_model/mid_trans.dart';
import '../models/payment_model/orange_money.dart';
import '../models/payment_model/pay_fast_model.dart';
import '../models/payment_model/pay_stack_model.dart';
import '../models/payment_model/paypal_model.dart';
import '../models/payment_model/paytm_model.dart';
import '../models/payment_model/razorpay_model.dart';
import '../models/payment_model/stripe_model.dart';
import '../models/payment_model/wallet_setting_model.dart';
import '../models/payment_model/xendit.dart';
import '../models/popular_destination.dart';
import '../models/product_model.dart';
import '../models/provider_serivce_model.dart';
import '../models/rating_model.dart';
import '../models/referral_model.dart';
import '../models/rental_vehicle_type.dart';
import '../models/review_attribute_model.dart';
import '../models/section_model.dart';
import '../models/story_model.dart';
import '../models/tax_model.dart';
import '../models/vehicle_type.dart';
import '../models/vendor_category_model.dart';
import '../models/vendor_model.dart';
import '../models/wallet_transaction_model.dart';
import '../models/worker_model.dart';
import '../screen_ui/multi_vendor_service/chat_screens/chat_video_container.dart';
import '../themes/app_them_data.dart';
import '../themes/show_toast_dialog.dart';
import '../utils/preferences.dart';
import '../widget/geoflutterfire/src/geoflutterfire.dart';
import '../widget/geoflutterfire/src/models/point.dart';
import 'package:http/http.dart' as http;
import '../utils/parallel.dart';

enum FirebaseEnv { defaultDb, staging }

/// Change this to switch between default / staging
const FirebaseEnv currentEnv = FirebaseEnv.defaultDb;

class FireStoreUtils {
  FireStoreUtils._privateConstructor();

  static final FireStoreUtils instance = FireStoreUtils._privateConstructor();

  static late FirebaseFirestore fireStore;

  /// Initialize Firestore with a FirebaseApp and optional databaseId
  void init(FirebaseApp app, {String? databaseId}) {
    fireStore = FirebaseFirestore.instanceFor(app: app, databaseId: databaseId);
  }

  static String getCurrentUid() {
    // Return empty for guests instead of crashing (currentUser is null).
    // Callers use this in queries/ids; "" yields no results rather than a crash.
    return auth.FirebaseAuth.instance.currentUser?.uid ?? "";
  }

  static Future<bool> isLogin() async {
    bool isLogin = false;
    if (auth.FirebaseAuth.instance.currentUser != null) {
      isLogin = await userExistOrNot(auth.FirebaseAuth.instance.currentUser!.uid);
    } else {
      isLogin = false;
    }
    return isLogin;
  }

  /// Whether a `users` document exists.
  ///
  /// The document it reads is the same one `getUserProfile()` reads moments
  /// later on the startup path - `isLogin()` here, then the profile in the
  /// splash - so the parsed model is put in [UserCache] on the way past and
  /// that second read is served from memory. One fewer network round trip
  /// between launching the app and seeing a screen.
  static Future<bool> userExistOrNot(String uid) async {
    bool isExist = false;

    await fireStore
        .collection(CollectionName.users)
        .doc(uid)
        .get()
        .then((value) {
          if (value.exists) {
            isExist = true;
            final data = value.data();
            if (data != null) {
              try {
                UserCache.put(uid, UserModel.fromJson(data));
              } catch (_) {
                // A profile this call cannot parse is not this call's problem;
                // it only has to answer whether the document exists.
              }
            }
          } else {
            isExist = false;
          }
        })
        .catchError((error) {
          log("Failed to check user exist: $error");
          isExist = false;
        });
    return isExist;
  }

  /// Reads a `users` document.
  ///
  /// Backed by [UserCache] so the same profile is not re-read on every
  /// rebuild or list row. Pass `forceRefresh: true` where the freshest copy
  /// matters (wallet balance, online status).
  static Future<UserModel?> getUserProfile(String uuid, {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = UserCache.get(uuid);
      if (cached != null) return cached;
    }
    UserModel? userModel;
    await fireStore
        .collection(CollectionName.users)
        .doc(uuid)
        .get()
        .then((value) {
          if (value.exists) {
            userModel = UserModel.fromJson(value.data()!);
          }
        })
        .catchError((error) {
          log("Failed to update user: $error");
          userModel = null;
        });
    final loaded = userModel;
    if (loaded != null) UserCache.put(uuid, loaded);
    return loaded;
  }

  static Future<UserModel?> getUserForChat(String uuid) async {
    UserModel? userModel;

    await fireStore
        .collection(CollectionName.providersWorkers)
        .doc(uuid)
        .get()
        .then((value) {
          if (value.exists) {
            userModel = UserModel.fromJson(value.data()!);
          }
        })
        .catchError((error) {
          log("Failed to update user: $error");
          userModel = null;
        });
    return userModel;
  }

  static Future<bool> updateUser(UserModel userModel) async {
    // The document is about to change - drop any cached copy.
    UserCache.invalidate(userModel.id);
    bool isUpdate = false;
    await fireStore
        .collection(CollectionName.users)
        .doc(userModel.id)
        .set(userModel.toJson())
        .whenComplete(() {
          Constant.userModel = userModel;
          isUpdate = true;
        })
        .catchError((error) {
          log("Failed to update user: $error");
          isUpdate = false;
        });
    return isUpdate;
  }

  /// Whether the customer app is switched off from the admin panel.
  ///
  /// Fails open. This is the very first read the splash screen makes, and an
  /// unhandled throw here - no connection, a rules change, anything - used to
  /// reject `redirectScreen()` and leave the app sitting on the splash art for
  /// ever with no error and no way forward.
  static Future<bool> isMaintenanceMode() async {
    bool isMaintenance = false;
    try {
      final value = await fireStore.collection(CollectionName.settings).doc('maintenance_settings').get();
      isMaintenance = value.data()?['isMaintenanceModeForCustomer'] == true;
      log("isMaintenance :: $isMaintenance");
    } catch (e) {
      log("isMaintenanceMode() could not be read, continuing :: $e");
    }
    return isMaintenance;
  }

  static Future<List<OnBoardingModel>> getOnBoardingList() async {
    List<OnBoardingModel> onBoardingModel = [];
    await fireStore
        .collection(CollectionName.onBoarding)
        .where("type", isEqualTo: "customer")
        .get()
        .then((value) {
          for (var element in value.docs) {
            OnBoardingModel documentModel = OnBoardingModel.fromJson(element.data());
            onBoardingModel.add(documentModel);
          }
        })
        .catchError((error) {
          log(error.toString());
        });
    return onBoardingModel;
  }

  /// The published delivery / service zones.
  ///
  /// Memoised because this is the **first** thing awaited by the service list,
  /// the food home, the dine-in home, the on-demand home and the category list,
  /// and nothing on any of those screens can be drawn until it returns. It is
  /// four documents that change when an admin edits a zone, i.e. never while
  /// somebody is shopping - but a GetX controller is rebuilt every time its
  /// route is pushed, so it was re-read on every entry to a section and on
  /// every trip back out of one.
  ///
  /// The de-duplication matters as much as the caching: opening a section can
  /// start the home controller and the dashboard controller in the same frame
  /// and both call this, which used to be two identical round trips with the
  /// screen waiting on the slower one.
  static Future<List<ZoneModel>?> getZone() {
    return FirestoreCache.remember<List<ZoneModel>>(_zoneCacheKey, _loadZone);
  }

  static const String _zoneCacheKey = 'zone';

  /// A cache key for something read per section.
  ///
  /// The section id is part of the key, not something to invalidate on: these
  /// queries all carry `where(section_id == Constant.sectionConstantModel.id)`,
  /// so caching them under a bare name would serve the food section's
  /// categories to the e-commerce section. Keying by id means switching section
  /// simply misses the cache and reads that section's own data - there is
  /// nothing to clear, and nothing that can be forgotten to be cleared.
  static String _sectionKey(String name) {
    return 'section:${Constant.sectionConstantModel?.id ?? 'none'}:$name';
  }

  static Future<List<ZoneModel>> _loadZone() async {
    List<ZoneModel> airPortList = [];
    await fireStore
        .collection(CollectionName.zone)
        .where('publish', isEqualTo: true)
        .get()
        .then((value) {
          for (var element in value.docs) {
            ZoneModel ariPortModel = ZoneModel.fromJson(element.data());
            airPortList.add(ariPortModel);
          }
        })
        .catchError((error) {
          log(error.toString());
        });
    return airPortList;
  }

  static Future<String?> referralAdd(ReferralModel ratingModel) async {
    try {
      await fireStore.collection(CollectionName.referral).doc(ratingModel.id).set(ratingModel.toJson());
    } catch (e, s) {
      print('FireStoreUtils.referralAdd $e $s');
      return "Couldn't review".tr;
    }
    return null;
  }

  static Future<ReferralModel?> getReferralUserByCode(String referralCode) async {
    ReferralModel? referralModel;
    try {
      await fireStore.collection(CollectionName.referral).where("referralCode", isEqualTo: referralCode).get().then((value) {
        if (value.docs.isNotEmpty) {
          referralModel = ReferralModel.fromJson(value.docs.first.data());
        }
      });
    } catch (e, s) {
      print('FireStoreUtils.firebaseCreateNewUser $e $s');
      return null;
    }
    return referralModel;
  }

    /// Memoised - 16 documents, and the first list the app draws after the splash.
  static Future<List<SectionModel>> getSections() {
    return FirestoreCache.remember<List<SectionModel>>('sections', _loadSections);
  }

  static Future<List<SectionModel>> _loadSections() async {
    List<SectionModel> sections = [];
    QuerySnapshot<Map<String, dynamic>> productsQuery = await fireStore.collection(CollectionName.sections).where("isActive", isEqualTo: true).orderBy("order", descending: false).get();

    await Future.forEach(productsQuery.docs, (QueryDocumentSnapshot<Map<String, dynamic>> document) {
      try {
        sections.add(SectionModel.fromJson(document.data()));
      } catch (e) {
        print('**-FireStoreUtils.getSection Parse error $e');
      }
    });
    return sections;
  }

    /// Memoised - one settings document, read alongside [getSections].
  static Future<List<dynamic>> getSectionBannerList() {
    return FirestoreCache.remember<List<dynamic>>('sectionBanners', _loadSectionBannerList);
  }

  static Future<List<dynamic>> _loadSectionBannerList() async {
    List<dynamic> sections = [];
    await fireStore.collection(CollectionName.settings).doc("AppHomeBanners").get().then((value) {
      if (value.exists) {
        sections = value.data()!['banners'] ?? [];
      }
    });
    return sections;
  }

    /// Memoised - three documents, and the value is also kept live by
  /// `GlobalSettingController.getCurrentCurrency()` for the whole session.
  static Future<CurrencyModel?> getCurrency() {
    return FirestoreCache.remember<CurrencyModel?>('currency', _loadCurrency);
  }

  static Future<CurrencyModel?> _loadCurrency() async {
    CurrencyModel? currency;
    await fireStore.collection(CollectionName.currency).where("isActive", isEqualTo: true).get().then((value) {
      if (value.docs.isNotEmpty) {
        currency = CurrencyModel.fromJson(value.docs.first.data());
      }
    });
    return currency;
  }

    /// Memoised for the cache's short TTL.
  ///
  /// The query bounds `startDate`/`endDate` against `DateTime.now()`, so the
  /// result is time-dependent - two minutes is well inside the resolution any
  /// advert campaign is scheduled at.
  static Future<List<AdvertisementModel>> getAllAdvertisement() {
    return FirestoreCache.remember<List<AdvertisementModel>>('advertisements', _loadAllAdvertisement);
  }

  static Future<List<AdvertisementModel>> _loadAllAdvertisement() async {
    List<AdvertisementModel> advertisementList = [];
    await fireStore
        .collection(CollectionName.advertisements)
        .where('status', isEqualTo: 'approved')
        .where('paymentStatus', isEqualTo: true)
        .where('startDate', isLessThanOrEqualTo: DateTime.now())
        .where('endDate', isGreaterThan: DateTime.now())
        .orderBy('priority', descending: false)
        .get()
        .then((value) {
          for (var element in value.docs) {
            AdvertisementModel advertisementModel = AdvertisementModel.fromJson(element.data());
            if (advertisementModel.isPaused == null || advertisementModel.isPaused == false) {
              advertisementList.add(advertisementModel);
            }
          }
        });
    return advertisementList;
  }

  static Future<List<FavouriteModel>> getFavouriteRestaurant() async {
    List<FavouriteModel> favouriteList = [];
    await fireStore.collection(CollectionName.favoriteVendor).where('user_id', isEqualTo: getCurrentUid()).where("section_id", isEqualTo: Constant.sectionConstantModel!.id).get().then((value) {
      for (var element in value.docs) {
        FavouriteModel favouriteModel = FavouriteModel.fromJson(element.data());
        favouriteList.add(favouriteModel);
      }
    });
    log("CollectionName.favoriteRestaurant :: ${favouriteList.length}");
    return favouriteList;
  }

  /// The customer's favourited vendors, as a query a list screen can page.
  ///
  /// Deliberately carries no `orderBy`, exactly like [vendorReviewsQuery]:
  /// [getFavouriteRestaurant] never had one, so adding one here would need a
  /// new composite index and would silently drop every favourite saved before
  /// that field existed. Without an `orderBy` Firestore orders by `__name__`,
  /// which is stable, so `startAfterDocument` pages correctly.
  static Query<Map<String, dynamic>> favouriteVendorQuery() {
    return fireStore.collection(CollectionName.favoriteVendor).where('user_id', isEqualTo: getCurrentUid()).where("section_id", isEqualTo: Constant.sectionConstantModel!.id);
  }

  /// The customer's favourited products, as a pageable query. See
  /// [favouriteVendorQuery] on why there is no `orderBy`.
  static Query<Map<String, dynamic>> favouriteItemQuery() {
    return fireStore.collection(CollectionName.favoriteItem).where('user_id', isEqualTo: getCurrentUid()).where("section_id", isEqualTo: Constant.sectionConstantModel!.id);
  }

  static Future<EmailTemplateModel?> getEmailTemplates(String type) async {
    EmailTemplateModel? emailTemplateModel;
    await fireStore.collection(CollectionName.emailTemplates).where('type', isEqualTo: type).get().then((value) {
      if (value.docs.isNotEmpty) {
        emailTemplateModel = EmailTemplateModel.fromJson(value.docs.first.data());
      }
    });
    return emailTemplateModel;
  }

  static Future<List<CashbackModel>> getCashbackList() async {
    List<CashbackModel> cashbackList = [];
    try {
      await fireStore
          .collection(CollectionName.cashback)
          .where('isEnabled', isEqualTo: true)
          .where('startDate', isLessThanOrEqualTo: Timestamp.now())
          .where('endDate', isGreaterThanOrEqualTo: Timestamp.now())
          .get()
          .then((event) {
            if (event.docs.isNotEmpty) {
              for (var element in event.docs) {
                CashbackModel cashbackModel = CashbackModel.fromJson(element.data());
                if (cashbackModel.customerIds == null || cashbackModel.customerIds?.contains(FireStoreUtils.getCurrentUid()) == true) {
                  cashbackList.add(cashbackModel);
                }
              }
            }
          });
    } catch (error, stackTrace) {
      log('Error fetching redeemed cashback data: $error', stackTrace: stackTrace);
    }

    return cashbackList;
  }

  static Future addDriverInbox(InboxModel inboxModel) async {
    return await fireStore.collection("chat_driver").doc(inboxModel.orderId).set(inboxModel.toJson()).then((document) {
      return inboxModel;
    });
  }

  static Future addDriverChat(ConversationModel conversationModel) async {
    return await fireStore.collection("chat_driver").doc(conversationModel.orderId).collection("thread").doc(conversationModel.id).set(conversationModel.toJson()).then((document) {
      return conversationModel;
    });
  }

  static Future addRestaurantInbox(InboxModel inboxModel) async {
    return await fireStore.collection("chat_store").doc(inboxModel.orderId).set(inboxModel.toJson()).then((document) {
      return inboxModel;
    });
  }

  static Future addRestaurantChat(ConversationModel conversationModel) async {
    return await fireStore.collection("chat_store").doc(conversationModel.orderId).collection("thread").doc(conversationModel.id).set(conversationModel.toJson()).then((document) {
      return conversationModel;
    });
  }

  static Future addWorkerInbox(InboxModel inboxModel) async {
    return await fireStore.collection("chat_worker").doc(inboxModel.orderId).set(inboxModel.toJson()).then((document) {
      return inboxModel;
    });
  }

  static Future addWorkerChat(ConversationModel conversationModel) async {
    return await fireStore.collection("chat_worker").doc(conversationModel.orderId).collection("thread").doc(conversationModel.id).set(conversationModel.toJson()).then((document) {
      return conversationModel;
    });
  }

  static Future addProviderInbox(InboxModel inboxModel) async {
    return await fireStore.collection("chat_provider").doc(inboxModel.orderId).set(inboxModel.toJson()).then((document) {
      return inboxModel;
    });
  }

  static Future addProviderChat(ConversationModel conversationModel) async {
    return await fireStore.collection("chat_provider").doc(conversationModel.orderId).collection("thread").doc(conversationModel.id).set(conversationModel.toJson()).then((document) {
      return conversationModel;
    });
  }

  static Future<List<TaxModel>?> getTaxList(String? sectionId) async {
    List<TaxModel> taxList = [];
    final location = Constant.selectedLocation.location;
    if (location?.latitude == null || location?.longitude == null) {
      return taxList; // no location context yet — no taxes to apply, no crash
    }
    String? country;
    try {
      final placeMarks = await placemarkFromCoordinates(location!.latitude!, location.longitude!);
      if (placeMarks.isNotEmpty) country = placeMarks.first.country;
    } catch (e) {
      log('getTaxList geocoding failed: $e');
    }
    if (country == null) return taxList;
    await fireStore
        .collection(CollectionName.tax)
        .where('sectionId', isEqualTo: sectionId)
        .where('country', isEqualTo: country)
        .where('enable', isEqualTo: true)
        .get()
        .then((value) {
          for (var element in value.docs) {
            TaxModel taxModel = TaxModel.fromJson(element.data());
            taxList.add(taxModel);
          }
        })
        .catchError((error) {
          log(error.toString());
        });

    return taxList;
  }

  static Future<List<DineInBookingModel>> getDineInBooking(bool isUpcoming) async {
    List<DineInBookingModel> list = [];

    if (isUpcoming) {
      await fireStore
          .collection(CollectionName.bookedTable)
          .where('authorID', isEqualTo: getCurrentUid())
          .where('date', isGreaterThan: Timestamp.now())
          .orderBy('date', descending: true)
          .orderBy('createdAt', descending: true)
          .get()
          .then((value) {
            for (var element in value.docs) {
              DineInBookingModel taxModel = DineInBookingModel.fromJson(element.data());
              list.add(taxModel);
            }
          })
          .catchError((error) {
            log(error.toString());
          });
    } else {
      await fireStore
          .collection(CollectionName.bookedTable)
          .where('authorID', isEqualTo: getCurrentUid())
          .where('date', isLessThan: Timestamp.now())
          .orderBy('date', descending: true)
          .orderBy('createdAt', descending: true)
          .get()
          .then((value) {
            for (var element in value.docs) {
              DineInBookingModel taxModel = DineInBookingModel.fromJson(element.data());
              list.add(taxModel);
            }
          })
          .catchError((error) {
            log(error.toString());
          });
    }

    return list;
  }

    /// The categories shown on a section home screen.
  ///
  /// Memoised per section: 27 documents on live, rewritten only by an admin,
  /// and re-read on every entry to the home screen and every return to it.
  static Future<List<VendorCategoryModel>> getHomeVendorCategory() {
    return FirestoreCache.remember<List<VendorCategoryModel>>(_sectionKey('homeVendorCategory'), _loadHomeVendorCategory);
  }

  static Future<List<VendorCategoryModel>> _loadHomeVendorCategory() async {
    List<VendorCategoryModel> list = [];
    await fireStore
        .collection(CollectionName.vendorCategories)
        .where("section_id", isEqualTo: Constant.sectionConstantModel!.id)
        .where("show_in_homepage", isEqualTo: true)
        .where('publish', isEqualTo: true)
        .get()
        .then((value) {
          for (var element in value.docs) {
            VendorCategoryModel walletTransactionModel = VendorCategoryModel.fromJson(element.data());
            list.add(walletTransactionModel);
          }
        })
        .catchError((error) {
          log(error.toString());
        });
    return list;
  }

  static Future<List<ProductModel>> getProductListByBrandId(String brandId) async {
    List<ProductModel> list = [];
    await fireStore
        .collection(CollectionName.vendorProducts)
        .where('brandID', isEqualTo: brandId)
        .where('publish', isEqualTo: true)
        .get()
        .then((value) {
          for (var element in value.docs) {
            ProductModel walletTransactionModel = ProductModel.fromJson(element.data());
            list.add(walletTransactionModel);
          }
        })
        .catchError((error) {
          log(error.toString());
        });
    return list;
  }

    /// Memoised per section - see [getHomeVendorCategory].
  static Future<List<BannerModel>> getHomeBottomBanner() {
    return FirestoreCache.remember<List<BannerModel>>(_sectionKey('bannerMiddle'), _loadHomeBottomBanner);
  }

  static Future<List<BannerModel>> _loadHomeBottomBanner() async {
    List<BannerModel> bannerList = [];
    await fireStore
        .collection(CollectionName.bannerItems)
        .where("is_publish", isEqualTo: true)
        .where("sectionId", isEqualTo: Constant.sectionConstantModel!.id)
        .where("position", isEqualTo: "middle")
        .orderBy("set_order", descending: false)
        .get()
        .then((value) {
          for (var element in value.docs) {
            BannerModel bannerHome = BannerModel.fromJson(element.data());
            bannerList.add(bannerHome);
          }
        });
    return bannerList;
  }

    /// Memoised - 17 published brands on live, and static between admin edits.
  static Future<List<BrandsModel>> getBrandList() {
    return FirestoreCache.remember<List<BrandsModel>>('brands', _loadBrandList);
  }

  static Future<List<BrandsModel>> _loadBrandList() async {
    List<BrandsModel> brandList = [];
    await fireStore.collection(CollectionName.brands).where("is_publish", isEqualTo: true).get().then((value) {
      for (var element in value.docs) {
        BrandsModel bannerHome = BrandsModel.fromJson(element.data());
        brandList.add(bannerHome);
      }
    });
    return brandList;
  }

  static Future<bool?> setBookedOrder(DineInBookingModel orderModel) async {
    bool isAdded = false;
    await fireStore
        .collection(CollectionName.bookedTable)
        .doc(orderModel.id)
        .set(orderModel.toJson())
        .then((value) {
          isAdded = true;
        })
        .catchError((error) {
          log("Failed to update user: $error");
          isAdded = false;
        });
    return isAdded;
  }

  static Future<List> getVendorCuisines(String id) async {
    List tagList = [];
    List prodTagList = [];
    QuerySnapshot<Map<String, dynamic>> productsQuery = await fireStore.collection(CollectionName.vendorProducts).where('vendorID', isEqualTo: id).get();
    await Future.forEach(productsQuery.docs, (QueryDocumentSnapshot<Map<String, dynamic>> document) {
      if (document.data().containsKey("categoryID") && document.data()['categoryID'].toString().isNotEmpty) {
        prodTagList.add(document.data()['categoryID']);
      }
    });
    QuerySnapshot<Map<String, dynamic>> catQuery = await fireStore.collection(CollectionName.vendorCategories).where('publish', isEqualTo: true).get();
    await Future.forEach(catQuery.docs, (QueryDocumentSnapshot<Map<String, dynamic>> document) {
      Map<String, dynamic> catDoc = document.data();
      if (catDoc.containsKey("id") && catDoc['id'].toString().isNotEmpty && catDoc.containsKey("title") && catDoc['title'].toString().isNotEmpty && prodTagList.contains(catDoc['id'])) {
        tagList.add(catDoc['title']);
      }
    });
    return tagList;
  }

  static Future<List<FavouriteItemModel>> getFavouriteItem() async {
    List<FavouriteItemModel> favouriteList = [];
    await fireStore.collection(CollectionName.favoriteItem).where('user_id', isEqualTo: getCurrentUid()).where("section_id", isEqualTo: Constant.sectionConstantModel!.id).get().then((value) {
      for (var element in value.docs) {
        FavouriteItemModel favouriteModel = FavouriteItemModel.fromJson(element.data());
        favouriteList.add(favouriteModel);
      }
    });
    return favouriteList;
  }

  /// One vendor, memoised by id for the cache's short TTL.
  ///
  /// This is read from list `itemBuilder`s - the favourites screen prices every
  /// visible row through a `FutureBuilder` that calls it - so a rebuild used to
  /// issue a fresh document read for every row on screen, and scrolling issued
  /// them again. Vendor documents are not written by the customer app, so
  /// holding one for a couple of minutes changes nothing a customer can see.
  static Future<VendorModel?> getVendorById(String vendorId) {
    return FirestoreCache.remember<VendorModel?>('vendor:$vendorId', () => _loadVendorById(vendorId));
  }

  static Future<VendorModel?> _loadVendorById(String vendorId) async {
    VendorModel? vendorModel;
    try {
      await fireStore.collection(CollectionName.vendors).doc(vendorId).get().then((value) {
        if (value.exists) {
          vendorModel = VendorModel.fromJson(value.data()!);
        }
      });
    } catch (e, s) {
      log('FireStoreUtils.firebaseCreateNewUser $e $s');
      return null;
    }
    return vendorModel;
  }

  /// One product, memoised by id - see [getVendorById].
  ///
  /// Deliberately **not** used by the stock decrement at order placement: that
  /// path calls [setProduct] straight after, so it needs the server's copy. It
  /// reads through this too, but writes invalidate the entry.
  static Future<ProductModel?> getProductById(String productId) {
    return FirestoreCache.remember<ProductModel?>('product:$productId', () => _loadProductById(productId));
  }

  static Future<ProductModel?> _loadProductById(String productId) async {
    ProductModel? vendorCategoryModel;
    try {
      await fireStore.collection(CollectionName.vendorProducts).doc(productId).get().then((value) {
        if (value.exists) {
          vendorCategoryModel = ProductModel.fromJson(value.data()!);
        }
      });
    } catch (e, s) {
      log('FireStoreUtils.firebaseCreateNewUser $e $s');
      return null;
    }
    return vendorCategoryModel;
  }

  static Future<List<GiftCardsModel>> getGiftCard() async {
    List<GiftCardsModel> giftCardModelList = [];
    QuerySnapshot<Map<String, dynamic>> currencyQuery = await fireStore.collection(CollectionName.giftCards).where("isEnable", isEqualTo: true).get();
    await Future.forEach(currencyQuery.docs, (QueryDocumentSnapshot<Map<String, dynamic>> document) {
      try {
        log(document.data().toString());
        giftCardModelList.add(GiftCardsModel.fromJson(document.data()));
      } catch (e) {
        debugPrint('FireStoreUtils.get Currency Parse error $e');
      }
    });
    return giftCardModelList;
  }

  static Future<bool?> setWalletTransaction(WalletTransactionModel walletTransactionModel) async {
    bool isAdded = false;
    await fireStore
        .collection(CollectionName.wallet)
        .doc(walletTransactionModel.id)
        .set(walletTransactionModel.toJson())
        .then((value) {
          isAdded = true;
        })
        .catchError((error) {
          log("Failed to update user: $error");
          isAdded = false;
        });
    return isAdded;
  }

  /// One settings document, or null when it could not be read.
  ///
  /// Errors are swallowed per document on purpose. [getSettings] starts every
  /// read before awaiting any of them, and an unawaited future that throws is
  /// an unhandled error - so each one has to carry its own failure. It is also
  /// better behaviour than the code this replaced: seven sequential awaits in
  /// one try block meant the first failure silently skipped the six settings
  /// after it.
  static Future<DocumentSnapshot<Map<String, dynamic>>?> _settingsDoc(String documentId) async {
    try {
      return await fireStore.collection(CollectionName.settings).doc(documentId).get();
    } catch (e) {
      log("getSettings() could not read settings/$documentId :: $e");
      return null;
    }
  }

  /// One settings document, applied from the device first and then from the
  /// server.
  ///
  /// Every launch used to wait for the server's copy of all seven documents
  /// before the splash screen could close - and `globalSettings` alone is
  /// 129.5 KB on live, 127.7 KB of it a ringtone inlined for the driver app that
  /// this app never plays. The copy Firestore already keeps on the device is
  /// now applied at once; the server's copy is still requested every launch and
  /// applied the moment it arrives, so an admin change still lands within the
  /// same launch. A first launch - nothing on the device yet - waits for the
  /// server exactly as before. The driver app's `_readSettings` has worked this
  /// way since Session 20.
  ///
  /// [apply] is handed `null` in exactly the cases the old code took its "not
  /// there" branch: the server says the document does not exist, or there was
  /// no copy on the device and the server could not be reached either. A failed
  /// server read after a device copy was applied changes nothing, which is also
  /// what the old `get()` did offline - it fell back to that same copy.
  static Future<void> _loadSettingsDoc(String documentId, void Function(Map<String, dynamic>? data) apply) async {
    // Each document is applied on its own, so one malformed value can no longer
    // abandon the documents after it the way one shared `try` did.
    void applySafely(Map<String, dynamic>? data) {
      try {
        apply(data);
      } catch (e) {
        log("getSettings() could not apply settings/$documentId :: $e");
      }
    }

    bool servedFromDevice = false;
    try {
      final DocumentSnapshot<Map<String, dynamic>> cached =
          await fireStore.collection(CollectionName.settings).doc(documentId).get(const GetOptions(source: Source.cache));
      final Map<String, dynamic>? data = cached.data();
      if (cached.exists && data != null) {
        applySafely(data);
        servedFromDevice = true;
      }
    } catch (e) {
      // Nothing on the device yet: a first launch, or cleared app data.
    }

    // Started either way. [_settingsDoc] swallows its own errors, which matters
    // because this future is not awaited when the device copy was used.
    final Future<void> fromServer = _settingsDoc(documentId).then((DocumentSnapshot<Map<String, dynamic>>? snapshot) {
      if (snapshot == null) {
        if (!servedFromDevice) applySafely(null);
        return;
      }
      applySafely(snapshot.exists ? snapshot.data() : null);
    });

    if (!servedFromDevice) await fromServer;
  }

  static Future<void> getSettings() async {
    try {
      // Every settings document read here is independent of the others - each
      // one only writes its own Constant - so all seven are started together.
      // Each is applied from the device first and corrected from the server;
      // see [_loadSettingsDoc].
      final Future<void> restaurantReq = _loadSettingsDoc('vendor', (Map<String, dynamic>? data) {
        if (data != null) {
          Constant.isSubscriptionModelApplied = data['subscription_model'] ?? false;
        } else {
          Constant.isSubscriptionModelApplied = false;
        }
      });

      final Future<void> globalSettingsReq = _loadSettingsDoc('globalSettings', (Map<String, dynamic>? data) {
        if (data != null) {
          Constant.isEnableAdsFeature = data['isEnableAdsFeature'] ?? false;
          Constant.isSelfDeliveryFeature = data['isSelfDelivery'] ?? false;
          Constant.defaultCountryCode = data['defaultCountryCode'] ?? '';
          Constant.taxScope = data['taxScope'] ?? "";
          String? colorStr = data['app_customer_color'];
          if (colorStr != null && colorStr.isNotEmpty) {
            AppThemeData.primary300 = Color(int.parse(colorStr.replaceFirst("#", "0xff")));
          }
        }
      });

      final Future<void> cashbackReq = _loadSettingsDoc('cashbackOffer', (Map<String, dynamic>? data) {
        if (data != null) {
          Constant.isCashbackActive = data["isEnable"] ?? false;
        } else {
          Constant.isCashbackActive = false;
        }
      });

      final Future<void> driverNearByReq = _loadSettingsDoc('DriverNearBy', (Map<String, dynamic>? data) {
        if (data != null) {
          Constant.selectedMapType = data["selectedMapType"] ?? Constant.selectedMapType;
          Constant.mapType = data["mapType"] ?? Constant.mapType;
          // Keeps the map the admin chose on the device, so the next launch
          // draws it from the first frame instead of guessing until this read
          // comes back.
          Constant.rememberMapSettings();
        }
      });

      final Future<void> storyReq = _loadSettingsDoc('story', (Map<String, dynamic>? data) {
        if (data != null) {
          Constant.storyEnable = data['isEnabled'] ?? false;
        } else {
          Constant.storyEnable = false;
        }
      });

      final Future<void> emailReq = _loadSettingsDoc('emailSetting', (Map<String, dynamic>? data) {
        if (data != null) {
          Constant.mailSettings = MailSettings.fromJson(data);
        }
      });

      final Future<void> specialDiscountReq = _loadSettingsDoc('specialDiscountOffer', (Map<String, dynamic>? data) {
        if (data != null) {
          Constant.specialDiscountOffer = data["isEnable"] ?? false;
        } else {
          Constant.specialDiscountOffer = false;
        }
      });

      fireStore.collection(CollectionName.settings).doc("DriverNearBy").snapshots().listen((event) {
        if (event.exists && event.data() != null) {
          Constant.distanceType = event.data()?["distanceType"] ?? "km";
          Constant.isEnableOTPTripStart = event.data()?["enableOTPTripStart"] ?? false;
          Constant.isEnableOTPTripStartForRental = event.data()?["enableOTPTripStartForRental"] ?? false;
        }
      });

      fireStore.collection(CollectionName.settings).doc("googleMapKey").snapshots().listen((event) {
        if (event.exists && event.data() != null) {
          Constant.mapAPIKey = event.data()?["key"] ?? "";
        }
      });
      fireStore.collection(CollectionName.settings).doc("placeHolderImage").snapshots().listen((event) {
        if (event.exists && event.data() != null) {
          Constant.placeHolderImage = event.data()?["image"] ?? "";
        }
      });

      fireStore.collection(CollectionName.settings).doc("notification_setting").snapshots().listen((event) {
        if (event.exists) {
          Constant.senderId = event.data()?["senderId"];
          Constant.jsonNotificationFileURL = event.data()?["serviceJson"];
        }
      });

      // `privacyPolicy` and `termsAndConditions` are **not** read here.
      //
      // They used to be, as two permanent `snapshots()` listeners opened during
      // startup. Measured against the live project those two documents are
      // 69.8 KB and 51.9 KB - 122 KB pulled down before the first screen is
      // drawn, on every launch, for text that is only ever displayed if the
      // customer opens Privacy Policy or Terms from the profile menu.
      //
      // Nothing is lost by not reading them. `TermsAndConditionScreen` fetches
      // the document itself when it opens and only falls back to these
      // `Constant`s if its own read fails, so they were never the primary
      // source - and that screen now writes what it fetched back into them, so
      // the fallback is warm from the first visit onwards.
      //
      // See `TermsAndConditionScreen._fetchContent`.

      // Bidding / counter-offer configuration. Kept live so the admin's global
      // switch takes effect without an app restart, and defaulted to "off" so
      // a missing document can never turn bidding on by accident.
      fireStore.collection(CollectionName.settings).doc(BiddingSettings.documentId).snapshots().listen((event) {
        Constant.biddingSettings = event.exists ? BiddingSettings.fromJson(event.data()) : BiddingSettings.disabled;
      }, onError: (Object error) {
        log("biddingSettings listener error: $error");
        Constant.biddingSettings = BiddingSettings.disabled;
      });

      // Driver-created trips: the radius that decides which posted trips this
      // customer is shown. Live, so an admin change reaches customers without
      // an app restart; absent means no radius, which lists every trip.
      fireStore.collection(CollectionName.settings).doc(DriverTripSettings.documentId).snapshots().listen((event) {
        Constant.driverTripSettings = event.exists ? DriverTripSettings.fromJson(event.data()) : DriverTripSettings.defaults;
      }, onError: (Object error) {
        log("driverTripsSettings listener error: $error");
        Constant.driverTripSettings = DriverTripSettings.defaults;
      });

      fireStore.collection(CollectionName.settings).doc("walletSettings").snapshots().listen((event) {
        if (event.exists && event.data() != null) {
          Constant.walletSetting = event.data()?["isEnabled"] ?? false;
        }
      });

      fireStore.collection(CollectionName.settings).doc("Version").snapshots().listen((event) {
        if (event.exists && event.data() != null) {
          Constant.googlePlayLink = event.data()?["googlePlayLink"] ?? '';
          Constant.appStoreLink = event.data()?["appStoreLink"] ?? '';
          Constant.appVersion = event.data()?["app_version"] ?? '';
          Constant.websiteUrl = event.data()?["websiteUrl"] ?? '';
        }
      });

      await Future.wait(<Future<void>>[
        restaurantReq,
        globalSettingsReq,
        cashbackReq,
        driverNearByReq,
        storyReq,
        emailReq,
        specialDiscountReq,
      ]);
    } catch (e) {
      log("getSettings() Error: $e");
    }
  }

  static Future<List<GiftCardsOrderModel>> getGiftHistory() async {
    List<GiftCardsOrderModel> giftCardsOrderList = [];
    await fireStore.collection(CollectionName.giftPurchases).where("userid", isEqualTo: FireStoreUtils.getCurrentUid()).get().then((value) {
      for (var element in value.docs) {
        GiftCardsOrderModel giftCardsOrderModel = GiftCardsOrderModel.fromJson(element.data());
        giftCardsOrderList.add(giftCardsOrderModel);
      }
    });
    return giftCardsOrderList;
  }

  static Future<List<OrderModel>> getAllOrder() async {
    List<OrderModel> list = [];

    print("Current UID: ${getCurrentUid()}");
    print("Section ID: ${Constant.sectionConstantModel?.id}");

    try {
      final snapshot =
          await fireStore
              .collection(CollectionName.vendorOrders)
              .where("authorID", isEqualTo: getCurrentUid())
              .where("section_id", isEqualTo: Constant.sectionConstantModel!.id)
              .orderBy("createdAt", descending: true)
              .get();

      print("Snapshot size: ${snapshot.docs.length}");

      for (var element in snapshot.docs) {
        OrderModel order = OrderModel.fromJson(element.data());
        print("Order fetched: ${order.id}"); // or other fields
        list.add(order);
      }

      print("Total Orders added to list: ${list.length}");
    } catch (e) {
      print("Error fetching orders: $e");
    }

    return list;
  }

  static Future<RatingModel?> getOrderReviewsByID(String orderId, String productID) async {
    RatingModel? ratingModel;

    await fireStore
        .collection(CollectionName.itemsReview)
        .where('orderid', isEqualTo: orderId)
        .where('productId', isEqualTo: productID)
        .get()
        .then((value) {
          if (value.docs.isNotEmpty) {
            ratingModel = RatingModel.fromJson(value.docs.first.data());
          }
        })
        .catchError((error) {
          log(error.toString());
        });
    return ratingModel;
  }

  static Future<VendorCategoryModel?> getVendorCategoryByCategoryId(String categoryId) async {
    VendorCategoryModel? vendorCategoryModel;
    try {
      await fireStore.collection(CollectionName.vendorCategories).doc(categoryId).get().then((value) {
        if (value.exists) {
          vendorCategoryModel = VendorCategoryModel.fromJson(value.data()!);
        }
      });
    } catch (e, s) {
      log('FireStoreUtils.firebaseCreateNewUser $e $s');
      return null;
    }
    return vendorCategoryModel;
  }

  static Future<ReviewAttributeModel?> getVendorReviewAttribute(String attributeId) async {
    ReviewAttributeModel? vendorCategoryModel;
    try {
      await fireStore.collection(CollectionName.reviewAttributes).doc(attributeId).get().then((value) {
        if (value.exists) {
          vendorCategoryModel = ReviewAttributeModel.fromJson(value.data()!);
        }
      });
    } catch (e, s) {
      log('FireStoreUtils.firebaseCreateNewUser $e $s');
      return null;
    }
    return vendorCategoryModel;
  }

  // static Future<bool?> setRatingModel(RatingModel ratingModel) async {
  //   bool isAdded = false;
  //   await fireStore
  //       .collection(CollectionName.itemsReview)
  //       .doc(ratingModel.id)
  //       .set(ratingModel.toJson())
  //       .then((value) {
  //         isAdded = true;
  //       })
  //       .catchError((error) {
  //         log("Failed to update user: $error");
  //         isAdded = false;
  //       });
  //   return isAdded;
  // }

  static Future<VendorModel?> updateVendor(VendorModel vendor) async {
    return await fireStore.collection(CollectionName.vendors).doc(vendor.id).set(vendor.toJson()).then((document) {
      return vendor;
    });
  }

  static Future<bool?> setProduct(ProductModel orderModel) async {
    bool isAdded = false;
    // Drop the memoised copy *before* the write, not after.
    //
    // The stock decrement at order placement does read-modify-write once per
    // cart line, and two lines can be two variants of the same product. If the
    // second line were served the copy the first line read, its decrement would
    // be computed from a quantity that is already out of date and the first
    // write would be lost. Invalidating here keeps that loop reading the
    // server's copy, exactly as it did before [getProductById] was memoised.
    FirestoreCache.invalidate('product:${orderModel.id}');
    await fireStore
        .collection(CollectionName.vendorProducts)
        .doc(orderModel.id)
        .set(orderModel.toJson())
        .then((value) {
          isAdded = true;
        })
        .catchError((error) {
          log("Failed to update user: $error");
          isAdded = false;
        });
    FirestoreCache.invalidate('product:${orderModel.id}');
    return isAdded;
  }

  static Future<ReferralModel?> getReferralUserBy() async {
    ReferralModel? referralModel;
    try {
      await fireStore.collection(CollectionName.referral).doc(getCurrentUid()).get().then((value) {
        referralModel = ReferralModel.fromJson(value.data()!);
      });
    } catch (e, s) {
      print('FireStoreUtils.firebaseCreateNewUser $e $s');
      return null;
    }
    return referralModel;
  }

  static Future<List<ProductModel>> getProductByVendorId(String vendorId) async {
    String selectedFoodType = Preferences.getString(Preferences.foodDeliveryType, defaultValue: "Delivery");
    List<ProductModel> list = [];
    log("GetProductByVendorId :: $selectedFoodType");
    if (selectedFoodType == "TakeAway") {
      await fireStore
          .collection(CollectionName.vendorProducts)
          .where("vendorID", isEqualTo: vendorId)
          .where('publish', isEqualTo: true)
          .orderBy("createdAt", descending: false)
          .get()
          .then((value) {
            for (var element in value.docs) {
              ProductModel productModel = ProductModel.fromJson(element.data());
              list.add(productModel);
            }
          })
          .catchError((error) {
            log(error.toString());
          });
    } else {
      await fireStore
          .collection(CollectionName.vendorProducts)
          .where("vendorID", isEqualTo: vendorId)
          .where("takeawayOption", isEqualTo: false)
          .where('publish', isEqualTo: true)
          .orderBy("createdAt", descending: false)
          .get()
          .then((value) {
            for (var element in value.docs) {
              ProductModel productModel = ProductModel.fromJson(element.data());
              list.add(productModel);
            }
          })
          .catchError((error) {
            log(error.toString());
          });
    }

    return list;
  }

  static Future<DeliveryCharge?> getDeliveryCharge() async {
    DeliveryCharge? deliveryCharge;
    try {
      await fireStore.collection(CollectionName.settings).doc("DeliveryCharge").get().then((value) {
        if (value.exists) {
          deliveryCharge = DeliveryCharge.fromJson(value.data()!);
        }
      });
    } catch (e, s) {
      log('FireStoreUtils.firebaseCreateNewUser $e $s');
      return null;
    }
    return deliveryCharge;
  }

  static Future<List<CouponModel>> getAllVendorPublicCoupons(String vendorId) async {
    List<CouponModel> coupon = [];

    await fireStore
        .collection(CollectionName.coupons)
        .where("vendorID", isEqualTo: vendorId)
        .where('expiresAt', isGreaterThanOrEqualTo: Timestamp.now())
        .where("isEnabled", isEqualTo: true)
        .where("isPublic", isEqualTo: true)
        .get()
        .then((value) {
          for (var element in value.docs) {
            CouponModel taxModel = CouponModel.fromJson(element.data());
            coupon.add(taxModel);
          }
        })
        .catchError((error) {
          log(error.toString());
        });
    print("coupon :::::::::::::::::${coupon.length}");
    return coupon;
  }

  static Future<List<CouponModel>> getAllVendorCoupons(String vendorId) async {
    List<CouponModel> coupon = [];

    await fireStore
        .collection(CollectionName.coupons)
        .where("vendorID", isEqualTo: vendorId)
        .where('expiresAt', isGreaterThanOrEqualTo: Timestamp.now())
        .where("isEnabled", isEqualTo: true)
        .get()
        .then((value) {
          for (var element in value.docs) {
            CouponModel taxModel = CouponModel.fromJson(element.data());
            coupon.add(taxModel);
          }
        })
        .catchError((error) {
          log(error.toString());
        });
    print("coupon :::::::::::::::::${coupon.length}");
    return coupon;
  }

  static Future<List<CashbackModel>> getAllCashbak() async {
    List<CashbackModel> cashbackList = [];
    await fireStore
        .collection(CollectionName.cashback)
        .get()
        .then((value) {
          cashbackList =
              value.docs.map((doc) {
                return CashbackModel.fromJson(doc.data());
              }).toList();
        })
        .catchError((error) {
          log(error.toString());
        });

    return cashbackList;
  }

  static Future<List<CashbackRedeemModel>> getRedeemedCashbacks(String cashbackId) async {
    List<CashbackRedeemModel> redeemedDocs = [];

    try {
      await fireStore.collection(CollectionName.cashbackRedeem).where('userId', isEqualTo: FireStoreUtils.getCurrentUid()).where('cashbackId', isEqualTo: cashbackId).get().then((value) {
        redeemedDocs =
            value.docs.map((doc) {
              return CashbackRedeemModel.fromJson(doc.data());
            }).toList();
      });
    } catch (error, stackTrace) {
      log('Error fetching redeemed cashback data: $error', stackTrace: stackTrace);
    }

    return redeemedDocs;
  }

  static Future<bool?> setCashbackRedeemModel(CashbackRedeemModel cashbackRedeemModel) async {
    bool isAdded = false;
    await fireStore
        .collection(CollectionName.cashbackRedeem)
        .doc(cashbackRedeemModel.id)
        .set(cashbackRedeemModel.toJson())
        .then((value) {
          isAdded = true;
        })
        .catchError((error) {
          log("Failed to update user: $error");
          isAdded = false;
        });
    return isAdded;
  }

  static Future<bool?> setOrder(OrderModel orderModel) async {
    bool isAdded = false;
    await fireStore
        .collection(CollectionName.vendorOrders)
        .doc(orderModel.id)
        .set(orderModel.toJson())
        .then((value) {
          isAdded = true;
        })
        .catchError((error) {
          log("Failed to update user: $error");
          isAdded = false;
        });
    return isAdded;
  }

  static Future<List<CouponModel>> getOfferByVendorId(String vendorId) async {
    List<CouponModel> couponList = [];
    await fireStore
        .collection(CollectionName.coupons)
        .where("vendorID", isEqualTo: vendorId)
        .where("isEnabled", isEqualTo: true)
        .where("isPublic", isEqualTo: true)
        .where('expiresAt', isGreaterThanOrEqualTo: Timestamp.now())
        .get()
        .then((value) {
          for (var element in value.docs) {
            CouponModel favouriteModel = CouponModel.fromJson(element.data());
            couponList.add(favouriteModel);
          }
        });
    return couponList;
  }

    /// Memoised - eight documents, and the whole collection was being re-read
  /// once per add-on while pricing a single product.
  static Future<List<AttributesModel>?> getAttributes() {
    return FirestoreCache.remember<List<AttributesModel>?>('vendorAttributes', _loadAttributes);
  }

  static Future<List<AttributesModel>?> _loadAttributes() async {
    List<AttributesModel> attributeList = [];
    await fireStore.collection(CollectionName.vendorAttributes).get().then((value) {
      for (var element in value.docs) {
        AttributesModel favouriteModel = AttributesModel.fromJson(element.data());
        attributeList.add(favouriteModel);
      }
    });
    return attributeList;
  }

  /// One vendor category, memoised by id.
  ///
  /// The restaurant screen asked for the category of **every product it had
  /// just loaded** - 30 sequential document reads for a vendor whose 30
  /// products all sit in one category, the duplicates then thrown away by a
  /// `Set` two lines later. The call sites now de-duplicate before they ask,
  /// and this makes a repeat ask free for the rest of the browse.
  static Future<VendorCategoryModel?> getVendorCategoryById(String categoryId) {
    return FirestoreCache.remember<VendorCategoryModel?>('vendorCategory:$categoryId', () => _loadVendorCategoryById(categoryId));
  }

  static Future<VendorCategoryModel?> _loadVendorCategoryById(String categoryId) async {
    VendorCategoryModel? vendorCategoryModel;
    try {
      await fireStore.collection(CollectionName.vendorCategories).doc(categoryId).get().then((value) {
        if (value.exists) {
          vendorCategoryModel = VendorCategoryModel.fromJson(value.data()!);
        }
      });
    } catch (e, s) {
      log('FireStoreUtils.firebaseCreateNewUser $e $s');
      return null;
    }
    return vendorCategoryModel;
  }

  /// The vendor's reviews, as a query the list screen can page through.
  ///
  /// Deliberately carries no orderBy: [getVendorReviews] never had one, and
  /// adding one here would both need a new composite index and silently drop
  /// every review saved before that field existed.
  static Query<Map<String, dynamic>> vendorReviewsQuery(String vendorId) {
    return fireStore.collection(CollectionName.itemsReview).where('VendorId', isEqualTo: vendorId);
  }

  static Future<List<RatingModel>> getVendorReviews(String vendorId) async {
    List<RatingModel> ratingList = [];
    await fireStore.collection(CollectionName.itemsReview).where('VendorId', isEqualTo: vendorId).get().then((value) {
      for (var element in value.docs) {
        RatingModel giftCardsOrderModel = RatingModel.fromJson(element.data());
        ratingList.add(giftCardsOrderModel);
      }
    });
    return ratingList;
  }

  static Future getPaymentSettingsData() async {
    // Thirteen independent settings documents, which used to be read one after
    // another: thirteen round trips in series in front of the ride screen, the
    // rental home and the order confirmations. They are now requested
    // together. Each is still written to Preferences in the original order,
    // and a failure still stops the ones after it and reaches the caller - see
    // [Parallel.applyInOrder].
    final Map<String, Future<void> Function(DocumentSnapshot<Map<String, dynamic>> value)> settingsInOrder = <String, Future<void> Function(DocumentSnapshot<Map<String, dynamic>> value)>{
      "payFastSettings": (DocumentSnapshot<Map<String, dynamic>> value) async {
        if (value.exists) {
          PayFastModel payFastModel = PayFastModel.fromJson(value.data()!);
          await Preferences.setString(Preferences.payFastSettings, jsonEncode(payFastModel.toJson()));
        }
      },
      "MercadoPago": (DocumentSnapshot<Map<String, dynamic>> value) async {
        if (value.exists) {
          MercadoPagoModel mercadoPagoModel = MercadoPagoModel.fromJson(value.data()!);
          await Preferences.setString(Preferences.mercadoPago, jsonEncode(mercadoPagoModel.toJson()));
        }
      },
      "paypalSettings": (DocumentSnapshot<Map<String, dynamic>> value) async {
        if (value.exists) {
          PayPalModel payPalModel = PayPalModel.fromJson(value.data()!);
          await Preferences.setString(Preferences.paypalSettings, jsonEncode(payPalModel.toJson()));
        }
      },
      "stripeSettings": (DocumentSnapshot<Map<String, dynamic>> value) async {
        if (value.exists) {
          StripeModel stripeModel = StripeModel.fromJson(value.data()!);
          await Preferences.setString(Preferences.stripeSettings, jsonEncode(stripeModel.toJson()));
        }
      },
      "flutterWave": (DocumentSnapshot<Map<String, dynamic>> value) async {
        if (value.exists) {
          FlutterWaveModel flutterWaveModel = FlutterWaveModel.fromJson(value.data()!);
          await Preferences.setString(Preferences.flutterWave, jsonEncode(flutterWaveModel.toJson()));
        }
      },
      "payStack": (DocumentSnapshot<Map<String, dynamic>> value) async {
        if (value.exists) {
          PayStackModel payStackModel = PayStackModel.fromJson(value.data()!);
          await Preferences.setString(Preferences.payStack, jsonEncode(payStackModel.toJson()));
        }
      },
      "PaytmSettings": (DocumentSnapshot<Map<String, dynamic>> value) async {
        if (value.exists) {
          PaytmModel paytmModel = PaytmModel.fromJson(value.data()!);
          await Preferences.setString(Preferences.paytmSettings, jsonEncode(paytmModel.toJson()));
        }
      },
      "walletSettings": (DocumentSnapshot<Map<String, dynamic>> value) async {
        if (value.exists) {
          WalletSettingModel walletSettingModel = WalletSettingModel.fromJson(value.data()!);
          await Preferences.setString(Preferences.walletSettings, jsonEncode(walletSettingModel.toJson()));
        }
      },
      "razorpaySettings": (DocumentSnapshot<Map<String, dynamic>> value) async {
        if (value.exists) {
          RazorPayModel razorPayModel = RazorPayModel.fromJson(value.data()!);
          await Preferences.setString(Preferences.razorpaySettings, jsonEncode(razorPayModel.toJson()));
        }
      },
      "CODSettings": (DocumentSnapshot<Map<String, dynamic>> value) async {
        if (value.exists) {
          CodSettingModel codSettingModel = CodSettingModel.fromJson(value.data()!);
          await Preferences.setString(Preferences.codSettings, jsonEncode(codSettingModel.toJson()));
        }
      },
      "midtrans_settings": (DocumentSnapshot<Map<String, dynamic>> value) async {
        if (value.exists) {
          MidTrans midTrans = MidTrans.fromJson(value.data()!);
          await Preferences.setString(Preferences.midTransSettings, jsonEncode(midTrans.toJson()));
        }
      },
      "orange_money_settings": (DocumentSnapshot<Map<String, dynamic>> value) async {
        if (value.exists) {
          OrangeMoney orangeMoney = OrangeMoney.fromJson(value.data()!);
          await Preferences.setString(Preferences.orangeMoneySettings, jsonEncode(orangeMoney.toJson()));
        }
      },
      "xendit_settings": (DocumentSnapshot<Map<String, dynamic>> value) async {
        if (value.exists) {
          Xendit xendit = Xendit.fromJson(value.data()!);
          await Preferences.setString(Preferences.xenditSettings, jsonEncode(xendit.toJson()));
        }
      },
    };
    await Parallel.applyInOrder<String, DocumentSnapshot<Map<String, dynamic>>>(
      settingsInOrder.keys,
      (String documentId) => fireStore.collection(CollectionName.settings).doc(documentId).get(),
      (String documentId, DocumentSnapshot<Map<String, dynamic>> value) => settingsInOrder[documentId]!(value),
    );
  }

  /// The wallet writer. Kept as a field so a test can swap the runner.
  static WalletLedger walletLedger = WalletLedger(FirestoreWalletTransactionRunner(fireStore, collection: CollectionName.users));

  /// Adds [amount] to `users/{userId}.wallet_amount`, negative to debit.
  ///
  /// Runs inside a Firestore transaction and writes only `wallet_amount`.
  /// This used to read the whole profile, add the delta in Dart and write the
  /// whole profile back, so two overlapping updates read the same balance and
  /// the later write discarded the earlier one.
  static Future<bool?> updateUserWallet({required String amount, required String userId}) async {
    final double? delta = WalletLedger.parseAmount(amount);
    if (delta == null) return false;
    try {
      final bool applied = await walletLedger.applyDelta(userId: userId, delta: delta);
      if (applied) {
        // The document just changed - drop any cached copy, and keep the
        // in-memory profile of the signed-in user in step with it.
        UserCache.invalidate(userId);
        final UserModel? current = Constant.userModel;
        if (current != null && current.id == userId) {
          current.walletAmount = (current.walletAmount ?? 0) + delta;
        }
      }
      return applied;
    } catch (error, stack) {
      log("Failed to update wallet: $error");
      log(stack.toString());
      return false;
    }
  }

  /// How long a nearby-vendor list keeps listening at most. See
  /// [getAllNearestRestaurant].
  static const Duration _vendorListLiveWindow = Duration(seconds: 20);

  static Stream<List<VendorModel>> getAllNearestRestaurantByCategoryId({bool? isDining, required String categoryId, bool ecommarce = false}) async* {
    try {
      // One controller per call. This used to be a single static controller,
      // re-created by every call, while the geohash query below - nine
      // Firestore listeners - was never cancelled: every visit to a store list
      // left those listeners running for the rest of the session, and because
      // each pushed into whichever controller was newest, an earlier screen's
      // query kept feeding its lists into the latest screen. The query now
      // stops when this stream's listener does (see `onCancel` below).
      final StreamController<List<VendorModel>> vendors = StreamController<List<VendorModel>>.broadcast();
      List<VendorModel> vendorList = [];
      Query<Map<String, dynamic>> query;
      if (ecommarce == true) {
        query =
            isDining == true
                ? fireStore.collection(CollectionName.vendors).where('categoryID', arrayContains: categoryId).where("enabledDiveInFuture", isEqualTo: true)
                : fireStore.collection(CollectionName.vendors).where('categoryID', arrayContains: categoryId);
      } else {
        query =
            isDining == true
                ? fireStore
                    .collection(CollectionName.vendors)
                    .where('categoryID', arrayContains: categoryId)
                    .where('zoneId', isEqualTo: Constant.selectedZone!.id.toString())
                    .where("enabledDiveInFuture", isEqualTo: true)
                : fireStore.collection(CollectionName.vendors).where('categoryID', arrayContains: categoryId).where('zoneId', isEqualTo: Constant.selectedZone!.id.toString());
      }
      GeoFirePoint center = Geoflutterfire().point(latitude: Constant.selectedLocation.location!.latitude ?? 0.0, longitude: Constant.selectedLocation.location!.longitude ?? 0.0);
      String field = 'g';

      Stream<List<DocumentSnapshot>> stream = Geoflutterfire()
          .collection(collectionRef: query)
          .within(center: center, radius: double.parse(Constant.sectionConstantModel!.nearByRadius.toString()), field: field, strictMode: true);

      // The list is read live only until the server's answer has arrived,
      // then the nine geohash listeners stop. Kept open, every write to any
      // nearby vendor re-sent every vendor document and re-ran the screens'
      // follow-up reads on the main thread - one of the Play ANR sources.
      // The first answer can come from the device cache and be partial, so
      // the listeners stay until a snapshot is all from the server, or
      // [_vendorListLiveWindow] at most. Re-opening the screen reads again.
      late final StreamSubscription<List<DocumentSnapshot>> geoQuery;
      bool liveStopped = false;
      Timer? liveWindow;
      void stopLive() {
        if (liveStopped) return;
        liveStopped = true;
        liveWindow?.cancel();
        geoQuery.cancel();
      }

      geoQuery = stream.listen((List<DocumentSnapshot> documentList) async {
        final bool fromServer = documentList.isNotEmpty && documentList.every((DocumentSnapshot d) => !d.metadata.isFromCache);
        vendorList.clear();
        for (var document in documentList) {
          final data = document.data() as Map<String, dynamic>;
          VendorModel vendorModel = VendorModel.fromJson(data);
          if ((Constant.isSubscriptionModelApplied == true || vendorModel.adminCommission?.isEnabled == true) && vendorModel.subscriptionPlan != null) {
            if (vendorModel.subscriptionTotalOrders == "-1") {
              vendorList.add(vendorModel);
            } else {
              if ((vendorModel.subscriptionExpiryDate != null && vendorModel.subscriptionExpiryDate!.toDate().isBefore(DateTime.now()) == false) || vendorModel.subscriptionPlan?.expiryDay == '-1') {
                if (vendorModel.subscriptionTotalOrders != '0') {
                  vendorList.add(vendorModel);
                }
              }
            }
          } else {
            vendorList.add(vendorModel);
          }
        }
        if (!vendors.isClosed) vendors.sink.add(vendorList);
        if (fromServer) stopLive();
      });
      liveWindow = Timer(_vendorListLiveWindow, stopLive);
      vendors.onCancel = () {
        stopLive();
        vendors.close();
      };

      yield* vendors.stream;
    } catch (e) {
      print(e);
    }
  }

  static Stream<List<VendorModel>> getAllNearestRestaurant({bool? isDining, bool ecommarce = false}) async* {
    try {
      // One controller per call. This used to be a single static controller,
      // re-created by every call, while the geohash query below - nine
      // Firestore listeners - was never cancelled: every visit to a store list
      // left those listeners running for the rest of the session, and because
      // each pushed into whichever controller was newest, an earlier screen's
      // query kept feeding its lists into the latest screen. The query now
      // stops when this stream's listener does (see `onCancel` below).
      final StreamController<List<VendorModel>> vendors = StreamController<List<VendorModel>>.broadcast();
      List<VendorModel> vendorList = [];
      Query<Map<String, dynamic>> query;
      if (ecommarce == true) {
        query =
            isDining == true
                ? fireStore.collection(CollectionName.vendors).where('section_id', isEqualTo: Constant.sectionConstantModel!.id).where("enabledDiveInFuture", isEqualTo: true)
                : fireStore.collection(CollectionName.vendors).where('section_id', isEqualTo: Constant.sectionConstantModel!.id);
      } else {
        query =
            isDining == true
                ? fireStore
                    .collection(CollectionName.vendors)
                    .where('section_id', isEqualTo: Constant.sectionConstantModel!.id)
                    .where('zoneId', isEqualTo: Constant.selectedZone?.id.toString())
                    .where("enabledDiveInFuture", isEqualTo: true)
                : fireStore.collection(CollectionName.vendors).where('section_id', isEqualTo: Constant.sectionConstantModel!.id).where('zoneId', isEqualTo: Constant.selectedZone?.id.toString());
      }

      GeoFirePoint center = Geoflutterfire().point(latitude: Constant.selectedLocation.location!.latitude ?? 0.0, longitude: Constant.selectedLocation.location!.longitude ?? 0.0);
      String field = 'g';

      Stream<List<DocumentSnapshot>> stream = Geoflutterfire()
          .collection(collectionRef: query)
          .within(center: center, radius: double.parse(Constant.sectionConstantModel!.nearByRadius.toString()), field: field, strictMode: true);

      // The list is read live only until the server's answer has arrived,
      // then the nine geohash listeners stop. Kept open, every write to any
      // nearby vendor re-sent every vendor document and re-ran the screens'
      // follow-up reads on the main thread - one of the Play ANR sources.
      // The first answer can come from the device cache and be partial, so
      // the listeners stay until a snapshot is all from the server, or
      // [_vendorListLiveWindow] at most. Re-opening the screen reads again.
      late final StreamSubscription<List<DocumentSnapshot>> geoQuery;
      bool liveStopped = false;
      Timer? liveWindow;
      void stopLive() {
        if (liveStopped) return;
        liveStopped = true;
        liveWindow?.cancel();
        geoQuery.cancel();
      }

      geoQuery = stream.listen((List<DocumentSnapshot> documentList) async {
        final bool fromServer = documentList.isNotEmpty && documentList.every((DocumentSnapshot d) => !d.metadata.isFromCache);
        vendorList.clear();
        for (var document in documentList) {
          final data = document.data() as Map<String, dynamic>;
          VendorModel vendorModel = VendorModel.fromJson(data);
          if ((Constant.isSubscriptionModelApplied == true || Constant.sectionConstantModel!.adminCommision?.isEnabled == true) && vendorModel.subscriptionPlan != null) {
            if (vendorModel.subscriptionTotalOrders == "-1") {
              vendorList.add(vendorModel);
            } else {
              if ((vendorModel.subscriptionExpiryDate != null && vendorModel.subscriptionExpiryDate!.toDate().isBefore(DateTime.now()) == false) || vendorModel.subscriptionPlan?.expiryDay == "-1") {
                if (vendorModel.subscriptionTotalOrders != '0') {
                  vendorList.add(vendorModel);
                }
              }
            }
          } else {
            vendorList.add(vendorModel);
          }
        }
        if (!vendors.isClosed) vendors.sink.add(vendorList);
        if (fromServer) stopLive();
      });
      liveWindow = Timer(_vendorListLiveWindow, stopLive);
      vendors.onCancel = () {
        stopLive();
        vendors.close();
      };

      yield* vendors.stream;
    } catch (e) {
      print(e);
    }
  }

  static Future<List<VendorCategoryModel>> getHomePageShowCategory() async {
    List<VendorCategoryModel> vendorCategoryList = [];
    await fireStore
        .collection(CollectionName.vendorCategories)
        .where("section_id", isEqualTo: Constant.sectionConstantModel!.id)
        .where("show_in_homepage", isEqualTo: true)
        .where('publish', isEqualTo: true)
        .get()
        .then((value) {
          for (var element in value.docs) {
            VendorCategoryModel vendorCategoryModel = VendorCategoryModel.fromJson(element.data());
            vendorCategoryList.add(vendorCategoryModel);
          }
        })
        .catchError((error) {
          log(error.toString());
        });
    return vendorCategoryList;
  }

  static Future<List<WalletTransactionModel>?> getWalletTransaction() async {
    List<WalletTransactionModel> walletTransactionList = [];
    log("FireStoreUtils.getCurrentUid() :: ${FireStoreUtils.getCurrentUid()}");
    await fireStore
        .collection(CollectionName.wallet)
        .where('user_id', isEqualTo: FireStoreUtils.getCurrentUid())
        .orderBy('date', descending: true)
        .get()
        .then((value) {
          for (var element in value.docs) {
            WalletTransactionModel walletTransactionModel = WalletTransactionModel.fromJson(element.data());
            walletTransactionList.add(walletTransactionModel);
          }
        })
        .catchError((error) {
          log(error.toString());
        });
    return walletTransactionList;
  }

  static Future<List<ProductModel>> getProductListByCategoryId(String categoryId, {Future<List<ProductModel>>? storeProducts}) async {
    List<ProductModel> productList = [];
    List<ProductModel> categorybyProductList = [];
    QuerySnapshot<Map<String, dynamic>> currencyQuery = await fireStore.collection(CollectionName.vendorProducts).where('categoryID', isEqualTo: categoryId).where('publish', isEqualTo: true).get();
    await Future.forEach(currencyQuery.docs, (QueryDocumentSnapshot<Map<String, dynamic>> document) {
      try {
        productList.add(ProductModel.fromJson(document.data()));
      } catch (e) {
        print('FireStoreUtils.getCurrencys Parse error $e');
      }
    });

    List<ProductModel> allProduct = await (storeProducts ?? getStoreProducts());

    for (var element in productList) {
      bool productIsInList = allProduct.any((product) => product.id == element.id);
      if (productIsInList) {
        categorybyProductList.add(element);
      }
    }

    return categorybyProductList;
  }

  /// Every product the nearby stores may show, within each store's plan limit.
  ///
  /// It does not depend on the category, so a screen that shows several
  /// categories can read it once and hand it to each
  /// [getProductListByCategoryId] call. The per-store product queries used to
  /// be awaited one store at a time; they now overlap and are applied in the
  /// original store order, and a failing query still fails the whole call.
  static Future<List<ProductModel>> getStoreProducts() async {
    List<VendorModel?> vendorList = await getAllStoresFuture();
    List<ProductModel> allProduct = <ProductModel>[];

    final List<List<ProductModel>> productsByStore = await Future.wait(<Future<List<ProductModel>>>[for (var vendor in vendorList) getAllProducts(vendor!.id.toString())]);
    for (int index = 0; index < vendorList.length; index++) {
      final vendor = vendorList[index]!;
      final value = productsByStore[index];
      if (Constant.isSubscriptionModelApplied == true || vendor.adminCommission?.isEnabled == true) {
        if (vendor.subscriptionPlan != null && Constant.isExpire(vendor) == false) {
          if (vendor.subscriptionPlan?.itemLimit == '-1') {
            allProduct.addAll(value);
          } else {
            int selectedProduct = value.length < int.parse(vendor.subscriptionPlan?.itemLimit ?? '0') ? (value.isEmpty ? 0 : (value.length)) : int.parse(vendor.subscriptionPlan?.itemLimit ?? '0');
            allProduct.addAll(value.sublist(0, selectedProduct));
          }
        }
      } else {
        allProduct.addAll(value);
      }
    }
    return allProduct;
  }

  static Future<List<ProductModel>> getAllProducts(String vendorId) async {
    List<ProductModel> products = [];

    QuerySnapshot<Map<String, dynamic>> productsQuery =
        await fireStore
            .collection(CollectionName.vendorProducts)
            .where("section_id", isEqualTo: Constant.sectionConstantModel!.id)
            .where('vendorID', isEqualTo: vendorId)
            .where('publish', isEqualTo: true)
            .orderBy('createdAt', descending: false)
            .get();
    await Future.forEach(productsQuery.docs, (QueryDocumentSnapshot<Map<String, dynamic>> document) {
      try {
        products.add(ProductModel.fromJson(document.data()));
      } catch (e) {
        print('product**-FireStoreUtils.getAllProducts Parse error $e');
      }
    });
    return products;
  }

  static Future<List<VendorModel>> getAllStoresFuture({String? categoryId, bool ecommarce = false}) async {
    List<VendorModel> vendors = [];

    try {
      Query<Map<String, dynamic>> collectionReference;
      if (ecommarce == true) {
        collectionReference =
            categoryId == null
                ? fireStore.collection(CollectionName.vendors).where("section_id", isEqualTo: Constant.sectionConstantModel!.id)
                : fireStore.collection(CollectionName.vendors).where("section_id", isEqualTo: Constant.sectionConstantModel!.id).where("categoryID", isEqualTo: categoryId);
      } else {
        collectionReference =
            categoryId == null
                ? fireStore.collection(CollectionName.vendors).where("section_id", isEqualTo: Constant.sectionConstantModel!.id).where("zoneId", isEqualTo: Constant.selectedZone!.id.toString())
                : fireStore
                    .collection(CollectionName.vendors)
                    .where("section_id", isEqualTo: Constant.sectionConstantModel!.id)
                    .where("categoryID", isEqualTo: categoryId)
                    .where("zoneId", isEqualTo: Constant.selectedZone!.id.toString());
      }
      GeoFirePoint center = Geoflutterfire().point(latitude: Constant.selectedLocation.location!.latitude ?? 0.0, longitude: Constant.selectedLocation.location!.longitude ?? 0.0);

      String field = 'g';

      List<DocumentSnapshot> documentList =
          await Geoflutterfire()
              .collection(collectionRef: collectionReference)
              .within(center: center, radius: double.parse(Constant.sectionConstantModel!.nearByRadius.toString()), field: field, strictMode: true)
              .first; // Fetch the data once as a Future

      if (documentList.isNotEmpty) {
        for (var document in documentList) {
          final data = document.data() as Map<String, dynamic>;
          VendorModel vendorModel = VendorModel.fromJson(data);

          if (Constant.isSubscriptionModelApplied == true || Constant.sectionConstantModel?.adminCommision?.isEnabled == true) {
            if (vendorModel.subscriptionPlan != null && Constant.isExpire(vendorModel) == false) {
              if (vendorModel.subscriptionTotalOrders == "-1") {
                vendors.add(vendorModel);
              } else {
                if ((vendorModel.subscriptionExpiryDate != null && vendorModel.subscriptionExpiryDate!.toDate().isBefore(DateTime.now()) == false) || vendorModel.subscriptionPlan?.expiryDay == "-1") {
                  if (vendorModel.subscriptionTotalOrders != '0') {
                    vendors.add(vendorModel);
                  }
                }
              }
            }
          } else {
            vendors.add(vendorModel);
          }
        }
      }
    } catch (e) {
      print('Error fetching vendors: $e');
    }

    return vendors;
  }

  static Future<NotificationModel?> getNotificationContent(String type) async {
    NotificationModel? notificationModel;
    await fireStore.collection(CollectionName.dynamicNotification).where('type', isEqualTo: type).get().then((value) {
      if (value.docs.isNotEmpty) {
        notificationModel = NotificationModel.fromJson(value.docs.first.data());
      } else {
        notificationModel = NotificationModel(id: "", message: "Notification setup is pending", subject: "setup notification", type: "");
      }
    });
    return notificationModel;
  }

  static Future<List<VendorCategoryModel>> getVendorCategory() async {
    List<VendorCategoryModel> list = [];
    await fireStore
        .collection(CollectionName.vendorCategories)
        .where('section_id', isEqualTo: Constant.sectionConstantModel!.id)
        .where('publish', isEqualTo: true)
        .get()
        .then((value) {
          for (var element in value.docs) {
            print("====>${value.docs.length}");
            VendorCategoryModel walletTransactionModel = VendorCategoryModel.fromJson(element.data());
            list.add(walletTransactionModel);
          }
        })
        .catchError((error) {
          log(error.toString());
        });
    return list;
  }

  static Future<GiftCardsOrderModel> placeGiftCardOrder(GiftCardsOrderModel giftCardsOrderModel) async {
    print("=====>");
    print(giftCardsOrderModel.toJson());
    await fireStore.collection(CollectionName.giftPurchases).doc(giftCardsOrderModel.id).set(giftCardsOrderModel.toJson());
    return giftCardsOrderModel;
  }

  static Future removeFavouriteRestaurant(FavouriteModel favouriteModel) async {
    await fireStore.collection(CollectionName.favoriteVendor).where("store_id", isEqualTo: favouriteModel.restaurantId).get().then((value) {
      value.docs.forEach((element) async {
        await fireStore.collection(CollectionName.favoriteVendor).doc(element.id).delete();
      });
    });
  }

  static Future<void> setFavouriteRestaurant(FavouriteModel favouriteModel) async {
    favouriteModel.sectionId = Constant.sectionConstantModel!.id;
    log("setFavouriteRestaurant :: ${favouriteModel.toJson()}");
    await fireStore.collection(CollectionName.favoriteVendor).add(favouriteModel.toJson());
  }

  static Future<void> removeFavouriteItem(FavouriteItemModel favouriteModel) async {
    try {
      final favoriteCollection = fireStore.collection(CollectionName.favoriteItem);
      final querySnapshot = await favoriteCollection.where("product_id", isEqualTo: favouriteModel.productId).get();
      for (final doc in querySnapshot.docs) {
        await favoriteCollection.doc(doc.id).delete();
      }
    } catch (e) {
      print("Error removing favourite item: $e");
    }
  }

  static Future<void> setFavouriteItem(FavouriteItemModel favouriteModel) async {
    favouriteModel.sectionId = Constant.sectionConstantModel!.id;
    await fireStore.collection(CollectionName.favoriteItem).add(favouriteModel.toJson());
  }

  static Future<Url> uploadChatImageToFireStorage(File image, BuildContext context) async {
    ShowToastDialog.showLoader("Please wait".tr);
    var uniqueID = const Uuid().v4();
    Reference upload = FirebaseStorage.instance.ref().child('images/$uniqueID.png');
    UploadTask uploadTask = upload.putFile(image);
    var storageRef = (await uploadTask.whenComplete(() {})).ref;
    var downloadUrl = await storageRef.getDownloadURL();
    var metaData = await storageRef.getMetadata();
    ShowToastDialog.closeLoader();
    return Url(mime: metaData.contentType ?? 'image', url: downloadUrl.toString());
  }

    /// Memoised for the cache's short TTL - see [getAllAdvertisement] on why a
  /// `Timestamp.now()` bound is safe to hold for two minutes.
  static Future<List<CouponModel>> getHomeCoupon() {
    return FirestoreCache.remember<List<CouponModel>>('homeCoupons', _loadHomeCoupon);
  }

  static Future<List<CouponModel>> _loadHomeCoupon() async {
    List<CouponModel> list = [];
    await fireStore
        .collection(CollectionName.coupons)
        .where('expiresAt', isGreaterThanOrEqualTo: Timestamp.now())
        .where("isEnabled", isEqualTo: true)
        .where("isPublic", isEqualTo: true)
        .get()
        .then((value) {
          for (var element in value.docs) {
            CouponModel walletTransactionModel = CouponModel.fromJson(element.data());
            list.add(walletTransactionModel);
          }
        })
        .catchError((error) {
          log(error.toString());
        });
    return list;
  }

    /// Memoised per section - see [getHomeVendorCategory].
  static Future<List<BannerModel>> getHomeTopBanner() {
    return FirestoreCache.remember<List<BannerModel>>(_sectionKey('bannerTop'), _loadHomeTopBanner);
  }

  static Future<List<BannerModel>> _loadHomeTopBanner() async {
    List<BannerModel> bannerList = [];
    await fireStore
        .collection(CollectionName.bannerItems)
        .where("is_publish", isEqualTo: true)
        .where("sectionId", isEqualTo: Constant.sectionConstantModel!.id)
        .where("position", isEqualTo: "top")
        .orderBy("set_order", descending: false)
        .get()
        .then((value) {
          for (var element in value.docs) {
            BannerModel bannerHome = BannerModel.fromJson(element.data());
            bannerList.add(bannerHome);
          }
        });
    return bannerList;
  }

    /// Memoised per section - 70 documents on live, re-read on every home load.
  static Future<List<StoryModel>> getStory() {
    return FirestoreCache.remember<List<StoryModel>>(_sectionKey('story'), _loadStory);
  }

  static Future<List<StoryModel>> _loadStory() async {
    List<StoryModel> storyList = [];
    await fireStore.collection(CollectionName.story).where('sectionID', isEqualTo: Constant.sectionConstantModel!.id).get().then((value) {
      print("Number of Stories Fetched: ${value.docs.length}");
      for (var element in value.docs) {
        StoryModel walletTransactionModel = StoryModel.fromJson(element.data());
        storyList.add(walletTransactionModel);
      }
    });
    return storyList;
  }

  static Future<GiftCardsOrderModel?> checkRedeemCode(String giftCode) async {
    GiftCardsOrderModel? giftCardsOrderModel;
    await fireStore.collection(CollectionName.giftPurchases).where("giftCode", isEqualTo: giftCode).get().then((value) {
      if (value.docs.isNotEmpty) {
        giftCardsOrderModel = GiftCardsOrderModel.fromJson(value.docs.first.data());
      }
    });
    return giftCardsOrderModel;
  }

  static Future<void> sendTopUpMail({required String amount, required String paymentMethod, required String tractionId}) async {
    EmailTemplateModel? emailTemplateModel = await FireStoreUtils.getEmailTemplates(Constant.walletTopup);

    String newString = emailTemplateModel!.message.toString();
    newString = newString.replaceAll("{username}", Constant.userModel!.firstName.toString() + Constant.userModel!.lastName.toString());
    newString = newString.replaceAll("{date}", DateFormat('yyyy-MM-dd').format(Timestamp.now().toDate()));
    newString = newString.replaceAll("{amount}", Constant.amountShow(amount: amount));
    newString = newString.replaceAll("{paymentmethod}", paymentMethod.toString());
    newString = newString.replaceAll("{transactionid}", tractionId.toString());
    newString = newString.replaceAll("{newwalletbalance}.", Constant.amountShow(amount: Constant.userModel!.walletAmount.toString()));
    await Constant.sendMail(subject: emailTemplateModel.subject, isAdmin: emailTemplateModel.isSendToAdmin, body: newString, recipients: [Constant.userModel!.email]);
  }

  static Future<ChatVideoContainer?> uploadChatVideoToFireStorage(BuildContext context, File video) async {
    try {
      ShowToastDialog.showLoader("Uploading video...");
      final String uniqueID = const Uuid().v4();
      final Reference videoRef = FirebaseStorage.instance.ref('videos/$uniqueID.mp4');
      final UploadTask uploadTask = videoRef.putFile(video, SettableMetadata(contentType: 'video/mp4'));
      await uploadTask;
      final String videoUrl = await videoRef.getDownloadURL();
      ShowToastDialog.showLoader("Generating thumbnail...");
      File thumbnail = await VideoCompress.getFileThumbnail(
        video.path,
        quality: 75, // 0 - 100
        position: -1, // Get the first frame
      );

      final String thumbnailID = const Uuid().v4();
      final Reference thumbnailRef = FirebaseStorage.instance.ref('thumbnails/$thumbnailID.jpg');
      final UploadTask thumbnailUploadTask = thumbnailRef.putData(thumbnail.readAsBytesSync(), SettableMetadata(contentType: 'image/jpeg'));
      await thumbnailUploadTask;
      final String thumbnailUrl = await thumbnailRef.getDownloadURL();
      var metaData = await thumbnailRef.getMetadata();
      ShowToastDialog.closeLoader();

      return ChatVideoContainer(videoUrl: Url(url: videoUrl.toString(), mime: metaData.contentType ?? 'video'), thumbnailUrl: thumbnailUrl);
    } catch (e) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Error: ${e.toString()}");
      return null;
    }
  }

  static Future<OrderModel?> getOrderByOrderId(String orderId) async {
    OrderModel? orderModel;
    try {
      await fireStore.collection(CollectionName.vendorOrders).doc(orderId).get().then((value) {
        if (value.data() != null) {
          orderModel = OrderModel.fromJson(value.data()!);
        }
      });
    } catch (e, s) {
      print('FireStoreUtils.firebaseCreateNewUser $e $s');
      return null;
    }
    return orderModel;
  }

  static Future<List<CouponModel>> getCabCoupon() async {
    List<CouponModel> ordersList = [];
    await fireStore
        .collection(CollectionName.promos)
        .where("sectionId", isEqualTo: Constant.sectionConstantModel!.id)
        .where('expiresAt', isGreaterThanOrEqualTo: Timestamp.now())
        .where("isEnabled", isEqualTo: true)
        .get()
        .then((value) {
          for (var element in value.docs) {
            CouponModel bannerHome = CouponModel.fromJson(element.data());
            ordersList.add(bannerHome);
          }
        });
    return ordersList;
  }

  static Future<List<CouponModel>> getParcelCoupon() async {
    List<CouponModel> ordersList = [];
    await fireStore
        .collection(CollectionName.parcelCoupons)
        .where("sectionId", isEqualTo: Constant.sectionConstantModel!.id)
        .where('expiresAt', isGreaterThanOrEqualTo: Timestamp.now())
        .where("isEnabled", isEqualTo: true)
        .get()
        .then((value) {
          for (var element in value.docs) {
            CouponModel bannerHome = CouponModel.fromJson(element.data());
            ordersList.add(bannerHome);
          }
        });
    return ordersList;
  }

  static Future<List<CouponModel>> getRentalCoupon() async {
    List<CouponModel> ordersList = [];
    await fireStore
        .collection(CollectionName.rentalCoupons)
        .where("sectionId", isEqualTo: Constant.sectionConstantModel!.id)
        .where('expiresAt', isGreaterThanOrEqualTo: Timestamp.now())
        .where("isEnabled", isEqualTo: true)
        .get()
        .then((value) {
          for (var element in value.docs) {
            CouponModel bannerHome = CouponModel.fromJson(element.data());
            ordersList.add(bannerHome);
          }
        });
    return ordersList;
  }

  static Future<bool?> deleteUser() async {
    bool? isDelete;
    try {
      await fireStore.collection(CollectionName.users).doc(FireStoreUtils.getCurrentUid()).delete();

      // delete user  from firebase auth
      await deleteAuthUser(FireStoreUtils.getCurrentUid());
      isDelete = true;
    } catch (e, s) {
      log('FireStoreUtils.firebaseCreateNewUser $e $s');
      return false;
    }
    return isDelete;
  }

  static Future<bool> deleteAuthUser(String uid) async {
    try {
      final user = auth.FirebaseAuth.instance.currentUser;
      if (user == null) {
        print("❌ No user is logged in.");
        return false;
      }

      final idToken = await user.getIdToken();
      final projectId = DefaultFirebaseOptions.currentPlatform.projectId;
      final url = Uri.parse('https://us-central1-$projectId.cloudfunctions.net/deleteUser');

      final response = await http.post(
        url,
        headers: {'Authorization': 'Bearer $idToken', 'Content-Type': 'application/json'},
        body: jsonEncode({
          'data': {'uid': uid}, // 👈 matches your Cloud Function structure
        }),
      );

      print("Response [${response.statusCode}]: ${response.body}");

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded['result']?['success'] == true || decoded['success'] == true;
      } else {
        print("⚠️ Cloud Function failed: ${response.body}");
        return false;
      }
    } catch (e) {
      print("❌ Error deleting driver: $e");
      return false;
    }
  }

  static Future<List<ParcelCategory>> getParcelServiceCategory() async {
    List<ParcelCategory> parcelCategoryList = [];
    await fireStore
        .collection(CollectionName.parcelCategory)
        .where('publish', isEqualTo: true)
        .where('sectionId', isEqualTo: Constant.sectionConstantModel!.id)
        .orderBy('set_order', descending: false)
        .get()
        .then((value) {
          for (var element in value.docs) {
            try {
              ParcelCategory category = ParcelCategory.fromJson(element.data());
              parcelCategoryList.add(category);
            } catch (e, stackTrace) {
              print('getParcelServiceCategory parse error: ${element.id} $e');
              print(stackTrace);
            }
          }
        });
    return parcelCategoryList;
  }

  static Future<List<ParcelWeightModel>> getParcelWeight() async {
    List<ParcelWeightModel> parcelWeightList = [];
    await fireStore.collection(CollectionName.parcelWeight).get().then((value) {
      for (var element in value.docs) {
        try {
          ParcelWeightModel category = ParcelWeightModel.fromJson(element.data());
          parcelWeightList.add(category);
        } catch (e, stackTrace) {
          print('getParcelWeight parse error: ${element.id} $e');
          print(stackTrace);
        }
      }
    });
    return parcelWeightList;
  }

  static Future<bool> setParcelOrder(ParcelOrderModel orderModel, double totalAmount) async {
    // try {
    //   final firestore = FirebaseFirestore.instance;
    //   final isNew = orderModel.id.isEmpty;
    //
    //   final docRef = firestore.collection(CollectionName.parcelOrders).doc(isNew ? null : orderModel.id);
    //   if (isNew) {
    //     orderModel.id = docRef.id;
    //   }
    //
    //   // Handle wallet payment if needed
    //   if (orderModel.paymentCollectByReceiver == false && orderModel.paymentMethod == "wallet") {
    //     WalletTransactionModel transactionModel = WalletTransactionModel(
    //       id: Constant.getUuid(),
    //       serviceType: 'parcel-service',
    //       amount: totalAmount,
    //       date: Timestamp.now(),
    //       paymentMethod: PaymentGateway.wallet.name,
    //       transactionUser: "customer",
    //       userId: FireStoreUtils.getCurrentUid(),
    //       isTopup: false,
    //       orderId: orderModel.id,
    //       note: "Order Amount debited".tr,
    //       paymentStatus: "success".tr,
    //     );
    //
    //     await FireStoreUtils.setWalletTransaction(transactionModel).then((value) async {
    //       if (value == true) {
    //         await FireStoreUtils.updateUserWallet(amount: "-$totalAmount", userId: FireStoreUtils.getCurrentUid());
    //       }
    //     });
    //   }
    //
    //   // Set the parcel order in Firestore
    //   await firestore.collection(CollectionName.parcelOrders).doc(orderModel.id).set(orderModel.toJson());
    //
    //   return true;
    // } catch (e) {
    //   debugPrint("Failed to place parcel order: $e");
    //   return false;
    // }
    return true;
  }

  static Future<void> sendParcelBookEmail({required ParcelOrderModel orderModel}) async {
    try {
      EmailTemplateModel? emailTemplateModel = await FireStoreUtils.getEmailTemplates(Constant.newParcelBook);

      String newString = emailTemplateModel!.message.toString();
      newString = newString.replaceAll("{passengername}", "${Constant.userModel!.firstName} ${Constant.userModel!.lastName}");
      newString = newString.replaceAll("{parcelid}", orderModel.id.toString());
      newString = newString.replaceAll("{date}", DateFormat('dd-MM-yyyy').format(orderModel.createdAt!.toDate()));
      newString = newString.replaceAll("{sendername}", orderModel.sender!.name.toString());
      newString = newString.replaceAll("{senderphone}", orderModel.sender!.phone.toString());
      newString = newString.replaceAll("{note}", orderModel.note.toString());
      newString = newString.replaceAll("{deliverydate}", DateFormat('dd-MM-yyyy').format(orderModel.receiverPickupDateTime!.toDate()));

      String subjectNewString = emailTemplateModel.subject.toString();
      subjectNewString = subjectNewString.replaceAll("{orderid}", orderModel.id.toString());
      await Constant.sendMail(subject: subjectNewString, isAdmin: emailTemplateModel.isSendToAdmin, body: newString, recipients: [Constant.userModel!.email]);
    } catch (e) {
      log("SIGNUP :: 22 :::::: $e");
    }
  }

  static Future<void> sendCabBookEmail({required CabOrderModel orderModel}) async {
    try {
      final sid = orderModel.sectionId ?? '';
      String vType = '';
      String brand = '';
      String carModel = '';
      String plate = '';
      if (orderModel.driver?.vehicleDetails?.containsKey(sid) == true) {
        final vehicle = orderModel.driver?.vehicleDetails?[sid];
        vType = vehicle['vehicleType']?.toString() ?? '';
        brand = vehicle['carBrand']?.toString() ?? '';
        carModel = vehicle['carModel']?.toString() ?? '';
        plate = vehicle['carPlateNumber']?.toString() ?? '';
      }
      EmailTemplateModel? emailTemplateModel = await FireStoreUtils.getEmailTemplates(Constant.newCabRideBook);
      String newString = emailTemplateModel!.message.toString();
      newString = newString.replaceAll("{passengername}", orderModel.author?.fullName() ?? '');
      newString = newString.replaceAll("{rideid}", orderModel.id.toString());
      newString = newString.replaceAll("{date}", DateFormat('dd-MM-yyyy').format(orderModel.createdAt!.toDate()));
      newString = newString.replaceAll("{time}", DateFormat('hh:mm a').format(orderModel.createdAt!.toDate()));
      newString = newString.replaceAll("{pickuplocation}", orderModel.sourceLocationName.toString());
      newString = newString.replaceAll("{dropofflocation}", orderModel.destinationLocationName.toString());
      newString = newString.replaceAll("{drivername}", orderModel.driver?.fullName() ?? '');
      newString = newString.replaceAll("{vehicle}", "${vType.toString()} | ${brand.toString()} | ${carModel.toString()}");
      newString = newString.replaceAll("{carnumber}", plate.toString());
      newString = newString.replaceAll("{driverphone}", orderModel.driver?.phoneNumber ?? '');
      String subjectNewString = emailTemplateModel.subject.toString();
      await Constant.sendMail(subject: subjectNewString, isAdmin: emailTemplateModel.isSendToAdmin, body: newString, recipients: [Constant.userModel!.email]);
    } catch (e) {
      log("SIGNUP :: 22 :::::: $e");
    }
  }

  static Future<void> sendCarBookEmail({required RentalOrderModel orderModel}) async {
    try {
      EmailTemplateModel? emailTemplateModel = await FireStoreUtils.getEmailTemplates(Constant.newCarRideBook);
      String newString = emailTemplateModel!.message.toString();
      newString = newString.replaceAll("{username}", orderModel.author?.fullName() ?? '');
      newString = newString.replaceAll("{passengername}", orderModel.author?.fullName() ?? '');
      newString = newString.replaceAll("{date}", DateFormat('dd-MM-yyyy').format(orderModel.createdAt!.toDate()));
      newString = newString.replaceAll("{time}", DateFormat('hh:mm a').format(orderModel.createdAt!.toDate()));
      newString = newString.replaceAll("{pickuplocation}", orderModel.sourceLocationName.toString());

      String subjectNewString = emailTemplateModel.subject.toString();
      await Constant.sendMail(subject: subjectNewString, isAdmin: emailTemplateModel.isSendToAdmin, body: newString, recipients: [Constant.userModel!.email]);
    } catch (e) {
      log("SIGNUP :: 22 :::::: $e");
    }
  }

  static Stream<List<ParcelOrderModel>> listenParcelOrders() {
    return fireStore
        .collection(CollectionName.parcelOrders)
        .where('authorID', isEqualTo: FireStoreUtils.getCurrentUid())
        .where('sectionId', isEqualTo: Constant.sectionConstantModel!.id)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            log("===>");
            print(doc.data());
            return ParcelOrderModel.fromJson(doc.data());
          }).toList();
        });
  }

    /// The vehicle types a section offers, memoised per section.
  ///
  /// 17 documents on live, written only by the admin - but the cab and
  /// intercity screens both awaited this **before the map was allowed to
  /// build**, so entering either section meant watching a spinner for a
  /// Firestore round trip before a single map tile was even requested.
  static Future<List<VehicleType>> getVehicleType() {
    return FirestoreCache.remember<List<VehicleType>>(_sectionKey('vehicleType'), _loadVehicleType);
  }

  static Future<List<VehicleType>> _loadVehicleType() async {
    List<VehicleType> vehicleTypeList = [];
    await fireStore.collection(CollectionName.vehicleType).where('sectionId', isEqualTo: Constant.sectionConstantModel!.id).where("isActive", isEqualTo: true).get().then((value) {
      for (var element in value.docs) {
        try {
          VehicleType category = VehicleType.fromJson(element.data());
          vehicleTypeList.add(category);
        } catch (e, stackTrace) {
          print('getVehicleType error: ${element.id} $e');
          print(stackTrace);
        }
      }
    });
    return vehicleTypeList;
  }

    /// Memoised per section - seven documents on live, and the intercity
  /// screen awaited it before its map could build.
  static Future<List<PopularDestination>> getPopularDestination() {
    return FirestoreCache.remember<List<PopularDestination>>(_sectionKey('popularDestinations'), _loadPopularDestination);
  }

  static Future<List<PopularDestination>> _loadPopularDestination() async {
    List<PopularDestination> popularDestination = [];
    await fireStore.collection(CollectionName.popularDestinations).where("sectionId", isEqualTo: Constant.sectionConstantModel!.id).where('is_publish', isEqualTo: true).get().then((value) {
      for (var element in value.docs) {
        try {
          PopularDestination category = PopularDestination.fromJson(element.data());
          popularDestination.add(category);
        } catch (e, stackTrace) {
          print('Get PopularDestination error: ${element.id} $e');
          print(stackTrace);
        }
      }
    });
    return popularDestination;
  }

  static Future cabOrderPlace(CabOrderModel orderModel) async {
    await fireStore.collection(CollectionName.rides).doc(orderModel.id).set(orderModel.toJson());
  }

  static Future parcelOrderPlace(ParcelOrderModel orderModel) async {
    await fireStore.collection(CollectionName.parcelOrders).doc(orderModel.id).set(orderModel.toJson());
  }

  static Future rentalOrderPlace(RentalOrderModel orderModel) async {
    await fireStore.collection(CollectionName.rentalOrders).doc(orderModel.id).set(orderModel.toJson());
  }

  static Future<CabOrderModel?> getCabOrderById(String orderId) async {
    CabOrderModel? orderModel;
    try {
      final doc = await fireStore.collection(CollectionName.rides).doc(orderId).get();
      if (doc.data() != null) {
        final model = CabOrderModel.fromJson(doc.data()!);
        if (model.rideType == "ride") {
          orderModel = model;
        }
      }
    } catch (e, s) {
      print('getCabOrderById error: $e\n$s');
      return null;
    }
    return orderModel;
  }

  static Future<CabOrderModel?> getIntercityOrder(String orderId) async {
    CabOrderModel? orderModel;
    try {
      final doc = await fireStore.collection(CollectionName.rides).doc(orderId).get();
      if (doc.data() != null) {
        final model = CabOrderModel.fromJson(doc.data()!);
        if (model.rideType == "intercity") {
          orderModel = model;
        }
      }
    } catch (e, s) {
      print('getCabOrderById error: $e\n$s');
      return null;
    }
    return orderModel;
  }

  static Future<UserModel?> getDriver(String userId) async {
    UserModel? userModel;

    try {
      final doc = await fireStore.collection(CollectionName.users).doc(userId).get();

      if (doc.data() != null) {
        userModel = UserModel.fromJson(doc.data()!);
      }
    } catch (e) {
      log("getDriver error: $e");
    }

    return userModel;
  }

  // static Future<List<CabOrderModel>> getCabDriverOrders() async {
  //   List<CabOrderModel> ordersList = [];
  //   await fireStore.collection(CollectionName.rides).where('authorID', isEqualTo: FireStoreUtils.getCurrentUid()).orderBy('createdAt', descending: true).get().then((value) {
  //     for (var element in value.docs) {
  //       CabOrderModel orderModel = CabOrderModel.fromJson(element.data());
  //       ordersList.add(orderModel);
  //     }
  //   });
  //   return ordersList;
  // }

  /// Paginated source for the customer's ride history.
  ///
  /// Deliberately the *same* where/orderBy shape as [getCabDriverOrders] so it
  /// reuses the existing composite index - only `limit()` and
  /// `startAfterDocument()` are added by the paginator, and neither affects
  /// index requirements.
  static Query<Map<String, dynamic>> cabOrdersQuery() {
    return fireStore
        .collection(CollectionName.rides)
        .where('authorID', isEqualTo: FireStoreUtils.getCurrentUid())
        .where('sectionId', isEqualTo: Constant.sectionConstantModel!.id)
        .orderBy('createdAt', descending: true);
  }

  /// Paginated source for the customer's parcel bookings.
  static Query<Map<String, dynamic>> parcelOrdersQuery() {
    return fireStore
        .collection(CollectionName.parcelOrders)
        .where('authorID', isEqualTo: FireStoreUtils.getCurrentUid())
        .where('sectionId', isEqualTo: Constant.sectionConstantModel!.id)
        .orderBy('createdAt', descending: true);
  }

  /// Paginated source for the customer's rental bookings.
  static Query<Map<String, dynamic>> rentalOrdersQuery() {
    return fireStore
        .collection(CollectionName.rentalOrders)
        .where('authorID', isEqualTo: FireStoreUtils.getCurrentUid())
        .where('sectionId', isEqualTo: Constant.sectionConstantModel!.id)
        .orderBy('createdAt', descending: true);
  }

  /// Paginated source for the customer's on-demand service bookings.
  static Query<Map<String, dynamic>> providerOrdersQuery() {
    return fireStore
        .collection(CollectionName.providerOrders)
        .where("authorID", isEqualTo: getCurrentUid())
        .where("sectionId", isEqualTo: Constant.sectionConstantModel!.id.toString())
        .orderBy("createdAt", descending: true);
  }

  /// Paginated source for the customer's store orders.
  static Query<Map<String, dynamic>> vendorOrdersQuery() {
    return fireStore
        .collection(CollectionName.vendorOrders)
        .where("authorID", isEqualTo: getCurrentUid())
        .where("section_id", isEqualTo: Constant.sectionConstantModel!.id)
        .orderBy("createdAt", descending: true);
  }

  /// Paginated source for the customer's wallet history.
  static Query<Map<String, dynamic>> walletTransactionQuery() {
    return fireStore.collection(CollectionName.wallet).where('user_id', isEqualTo: FireStoreUtils.getCurrentUid()).orderBy('date', descending: true);
  }

  static Stream<List<CabOrderModel>> getCabDriverOrders() {
    return fireStore
        .collection(CollectionName.rides)
        .where('authorID', isEqualTo: FireStoreUtils.getCurrentUid())
        .where('sectionId', isEqualTo: Constant.sectionConstantModel!.id)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((query) {
          List<CabOrderModel> ordersList = [];
          for (var element in query.docs) {
            ordersList.add(CabOrderModel.fromJson(element.data()));
          }
          return ordersList;
        });
  }

  static Future<List<CategoryModel>> getOnDemandCategory() async {
    List<CategoryModel> categoryList = [];
    await fireStore
        .collection(CollectionName.providerCategories)
        .where("sectionId", isEqualTo: Constant.sectionConstantModel!.id)
        .where("level", isEqualTo: 0)
        .where("publish", isEqualTo: true)
        .get()
        .then((value) {
          for (var element in value.docs) {
            CategoryModel orderModel = CategoryModel.fromJson(element.data());
            categoryList.add(orderModel);
          }
        });
    return categoryList;
  }

  static Future<CategoryModel?> getCategoryById(String categoryId) async {
    CategoryModel? categoryModel;
    await fireStore.collection(CollectionName.providerCategories).doc(categoryId).get().then((value) {
      if (value.exists) {
        categoryModel = CategoryModel.fromJson(value.data()!);
      }
    });
    return categoryModel;
  }

  static Future<List<ProviderServiceModel>> getProviderFuture({String categoryId = ''}) async {
    List<ProviderServiceModel> providerList = [];

    try {
      Query<Map<String, dynamic>> collectionReference;

      if (categoryId.isNotEmpty) {
        collectionReference = fireStore
            .collection(CollectionName.providersServices)
            .where("sectionId", isEqualTo: Constant.sectionConstantModel!.id)
            .where('categoryId', isEqualTo: categoryId)
            .where("publish", isEqualTo: true);
      } else {
        collectionReference = fireStore.collection(CollectionName.providersServices).where("sectionId", isEqualTo: Constant.sectionConstantModel!.id).where("publish", isEqualTo: true);
      }

      GeoFirePoint center = Geoflutterfire().point(latitude: Constant.selectedLocation.location!.latitude ?? 0.0, longitude: Constant.selectedLocation.location!.longitude ?? 0.0);

      String field = 'g';

      await Geoflutterfire()
          .collection(collectionRef: collectionReference)
          .within(center: center, radius: double.parse(Constant.sectionConstantModel!.nearByRadius.toString()), field: field, strictMode: true)
          .first
          .then((documentList) {
            for (var document in documentList) {
              ProviderServiceModel providerServiceModel = ProviderServiceModel.fromJson(document.data() as Map<String, dynamic>);

              if (Constant.isSubscriptionModelApplied == true || Constant.sectionConstantModel?.adminCommision?.isEnabled == true) {
                if (providerServiceModel.subscriptionPlan != null &&
                    Constant.isExpireDate(expiryDay: (providerServiceModel.subscriptionPlan?.expiryDay == '-1'), subscriptionExpiryDate: providerServiceModel.subscriptionExpiryDate) == false) {
                  if (providerServiceModel.subscriptionTotalOrders == "-1" || providerServiceModel.subscriptionTotalOrders != '0') {
                    providerList.add(providerServiceModel);
                  }
                }
              } else {
                providerList.add(providerServiceModel);
              }
            }
          })
          .catchError((error) {
            log('Error fetching providers: $error');
          });
    } catch (e) {
      log('Error in getProviderFuture: $e');
    }

    return providerList;
  }

  static Future<List<ProviderServiceModel>> getAllProviderServiceByAuthorId(String authId) async {
    List<ProviderServiceModel> providerService = [];
    await fireStore.collection(CollectionName.providersServices).where('author', isEqualTo: authId).where('publish', isEqualTo: true).orderBy('createdAt', descending: false).get().then((value) {
      for (var element in value.docs) {
        ProviderServiceModel orderModel = ProviderServiceModel.fromJson(element.data());
        providerService.add(orderModel);
      }
    });
    return providerService;
  }

  static Future<CategoryModel?> getSubCategoryById(String categoryId) async {
    CategoryModel? categoryModel;
    await fireStore.collection(CollectionName.providerCategories).doc(categoryId).get().then((value) {
      if (value.exists) {
        categoryModel = CategoryModel.fromJson(value.data()!);
      }
    });
    return categoryModel;
  }

  static Future<List<RatingModel>> getReviewByProviderServiceId(String serviceId) async {
    List<RatingModel> providerReview = [];
    await fireStore.collection(CollectionName.itemsReview).where('productId', isEqualTo: serviceId).get().then((value) {
      for (var element in value.docs) {
        RatingModel orderModel = RatingModel.fromJson(element.data());
        providerReview.add(orderModel);
      }
    });
    return providerReview;
  }

  static Future<List<ProviderServiceModel>> getProviderServiceByProviderId({required String providerId}) async {
    List<ProviderServiceModel> providerList = [];

    try {
      final collectionReference = fireStore
          .collection(CollectionName.providersServices)
          .where("author", isEqualTo: providerId)
          .where("sectionId", isEqualTo: Constant.sectionConstantModel!.id)
          .where("publish", isEqualTo: true);

      // Geolocation center point
      GeoFirePoint center = Geoflutterfire().point(latitude: Constant.selectedLocation.location!.latitude ?? 0.0, longitude: Constant.selectedLocation.location!.longitude ?? 0.0);

      String field = 'g';

      // Query within radius
      await Geoflutterfire()
          .collection(collectionRef: collectionReference)
          .within(center: center, radius: double.parse(Constant.sectionConstantModel!.nearByRadius.toString()), field: field, strictMode: true)
          .first
          .then((documentList) {
            for (var document in documentList) {
              ProviderServiceModel providerServiceModel = ProviderServiceModel.fromJson(document.data() as Map<String, dynamic>);

              //Subscription & Commission check
              if (Constant.isSubscriptionModelApplied == true || Constant.sectionConstantModel?.adminCommision?.isEnabled == true) {
                if (providerServiceModel.subscriptionPlan != null &&
                    Constant.isExpireDate(expiryDay: (providerServiceModel.subscriptionPlan?.expiryDay == '-1'), subscriptionExpiryDate: providerServiceModel.subscriptionExpiryDate) == false) {
                  if (providerServiceModel.subscriptionTotalOrders == "-1" || providerServiceModel.subscriptionTotalOrders != '0') {
                    providerList.add(providerServiceModel);
                  }
                }
              } else {
                providerList.add(providerServiceModel);
              }
            }
          })
          .catchError((error) {
            log('Error fetching provider services: $error');
          });
    } catch (e) {
      log('Error in getProviderServiceByProviderId: $e');
    }

    return providerList;
  }

  static Future<List<CouponModel>> getProviderCoupon(String providerId) async {
    List<CouponModel> offers = [];
    await fireStore
        .collection(CollectionName.providersCoupons)
        .where('providerId', isEqualTo: providerId)
        .where("isEnabled", isEqualTo: true)
        .where('sectionId', isEqualTo: Constant.sectionConstantModel!.id)
        .where('expiresAt', isGreaterThanOrEqualTo: Timestamp.now())
        .get()
        .then((value) {
          for (var element in value.docs) {
            CouponModel favouriteOndemandServiceModel = CouponModel.fromJson(element.data());
            offers.add(favouriteOndemandServiceModel);
          }
        });
    return offers;
  }

  static Future<List<CouponModel>> getProviderCouponAfterExpire(String providerId) async {
    List<CouponModel> coupon = [];
    await fireStore
        .collection(CollectionName.providersCoupons)
        .where('providerId', isEqualTo: providerId)
        .where('isEnabled', isEqualTo: true)
        .where('sectionId', isEqualTo: Constant.sectionConstantModel!.id)
        .where('isPublic', isEqualTo: true)
        .where('expiresAt', isGreaterThanOrEqualTo: Timestamp.now())
        .get()
        .then((value) {
          for (var element in value.docs) {
            CouponModel favouriteOndemandServiceModel = CouponModel.fromJson(element.data());
            coupon.add(favouriteOndemandServiceModel);
          }
        });
    return coupon;
  }

  static Future<OnProviderOrderModel> onDemandOrderPlace(OnProviderOrderModel orderModel, double totalAmount) async {
    DocumentReference documentReference;
    if (orderModel.id.isEmpty) {
      documentReference = fireStore.collection(CollectionName.providerOrders).doc();
      orderModel.id = documentReference.id;
    } else {
      documentReference = fireStore.collection(CollectionName.providerOrders).doc(orderModel.id);
    }
    await documentReference.set(orderModel.toJson());

    return orderModel;
  }

  static Future<void> sendOrderOnDemandServiceEmail({required OnProviderOrderModel orderModel}) async {
    try {
      String firstHTML = """
       <table style="width: 100%; border-collapse: collapse; border: 1px solid rgb(0, 0, 0);">
    <thead>
        <tr>
            <th style="text-align: left; border: 1px solid rgb(0, 0, 0);">Product Name<br></th>
            <th style="text-align: left; border: 1px solid rgb(0, 0, 0);">Quantity<br></th>
            <th style="text-align: left; border: 1px solid rgb(0, 0, 0);">Price<br></th>
            <th style="text-align: left; border: 1px solid rgb(0, 0, 0);">Total<br></th>
        </tr>
    </thead>
    <tbody>
    """;

      EmailTemplateModel? emailTemplateModel = await FireStoreUtils.getEmailTemplates(Constant.newOnDemandBook);

      if (emailTemplateModel != null) {
        String newString = emailTemplateModel.message.toString();
        newString = newString.replaceAll("{username}", "${Constant.userModel?.firstName ?? ''} ${Constant.userModel?.lastName ?? ''}");
        newString = newString.replaceAll("{orderid}", orderModel.id);
        newString = newString.replaceAll("{date}", DateFormat('dd-MM-yyyy').format(orderModel.createdAt.toDate()));
        newString = newString.replaceAll("{address}", orderModel.address!.getFullAddress());
        newString = newString.replaceAll("{paymentmethod}", orderModel.payment_method);

        double total = 0.0;
        double discount = 0.0;
        double taxAmount = 0.0;
        List<String> htmlList = [];

        if (orderModel.provider.disPrice == "" || orderModel.provider.disPrice == "0") {
          total = double.parse(orderModel.provider.price.toString()) * orderModel.quantity;
        } else {
          total = double.parse(orderModel.provider.disPrice.toString()) * orderModel.quantity;
        }

        String product = """
        <tr>
            <td style="width: 20%; border-top: 1px solid rgb(0, 0, 0);">${orderModel.provider.title}</td>
            <td style="width: 20%; border: 1px solid rgb(0, 0, 0);" rowspan="2">${orderModel.quantity}</td>
            <td style="width: 20%; border: 1px solid rgb(0, 0, 0);" rowspan="2">${Constant.amountShow(amount: (orderModel.provider.disPrice == "" || orderModel.provider.disPrice == "0") ? orderModel.provider.price.toString() : orderModel.provider.disPrice.toString())}</td>
            <td style="width: 20%; border: 1px solid rgb(0, 0, 0);" rowspan="2">${Constant.amountShow(amount: (total).toString())}</td>
        </tr>
    """;
        htmlList.add(product);

        if (orderModel.couponCode != null && orderModel.couponCode!.isNotEmpty) {
          discount = double.parse(orderModel.discount.toString());
        }
        List<String> taxHtmlList = [];
        if (orderModel.taxModel != null) {
          for (var element in orderModel.taxModel!) {
            taxAmount = taxAmount + Constant.getTaxValue(amount: (total - discount).toString(), taxModel: element);
            String taxHtml =
                """<span style="font-size: 1rem;">${element.title}: ${Constant.amountShow(amount: Constant.getTaxValue(amount: (total - discount).toString(), taxModel: element).toString())}${orderModel.taxModel!.indexOf(element) == orderModel.taxModel!.length - 1 ? "</span>" : "<br></span>"}""";
            taxHtmlList.add(taxHtml);
          }
        }

        var totalamount = total + taxAmount - discount;

        newString = newString.replaceAll("{subtotal}", Constant.amountShow(amount: total.toString()));
        newString = newString.replaceAll("{coupon}", '(${orderModel.couponCode.toString()})');
        newString = newString.replaceAll("{discountamount}", orderModel.couponCode == null ? "0.0" : Constant.amountShow(amount: orderModel.discount.toString()));
        newString = newString.replaceAll("{totalAmount}", Constant.amountShow(amount: totalamount.toString()));

        String tableHTML = htmlList.join();
        String lastHTML = "</tbody></table>";
        newString = newString.replaceAll("{productdetails}", firstHTML + tableHTML + lastHTML);
        newString = newString.replaceAll("{taxdetails}", taxHtmlList.join());
        newString = newString.replaceAll("{newwalletbalance}.", Constant.amountShow(amount: Constant.userModel?.walletAmount.toString()));

        String subjectNewString = emailTemplateModel.subject.toString();
        subjectNewString = subjectNewString.replaceAll("{orderid}", orderModel.id);
        await Constant.sendMail(subject: subjectNewString, isAdmin: emailTemplateModel.isSendToAdmin, body: newString, recipients: [Constant.userModel?.email]);
      }
    } catch (e) {
      log("SIGNUP :: 22 :::::: $e");
    }
  }

  static Future<void> updateOnDemandOrder(OnProviderOrderModel orderModel) async {
    if (orderModel.id.isEmpty) {
      throw Exception("Order ID cannot be empty");
    }

    try {
      final docRef = fireStore.collection(CollectionName.providerOrders).doc(orderModel.id);
      await docRef.set(orderModel.toJson(), SetOptions(merge: true));
    } catch (e) {
      print("Error updating OnDemand order: $e");
      rethrow;
    }
  }

  // static Future<void> updateOnDemandOrder(OnProviderOrderModel orderModel) async {
  //   if (orderModel.id.isEmpty) {
  //     throw Exception("Order ID cannot be empty");
  //   }
  //
  //   try {
  //     final docRef = fireStore.collection(CollectionName.providerOrders).doc(orderModel.id);
  //
  //     // Convert model to map
  //     final Map<String, dynamic> data = orderModel.toJson();
  //
  //     // Remove null values so we only update non-null fields
  //     final Map<String, dynamic> updateData = {};
  //     data.forEach((key, value) {
  //       if (value != null) {
  //         updateData[key] = value;
  //       }
  //     });
  //
  //     if (updateData.isNotEmpty) {
  //       await docRef.set(updateData, SetOptions(merge: true));
  //       print("Order ${orderModel.id} updated dynamically: $updateData");
  //     } else {
  //       print("No fields to update for order ${orderModel.id}");
  //     }
  //   } catch (e) {
  //     print("Error updating OnDemand order: $e");
  //     rethrow;
  //   }
  // }

  // static Future<List<OnProviderOrderModel>> getProviderOrders() async {
  //   List<OnProviderOrderModel> ordersList = [];
  //   await fireStore
  //       .collection(CollectionName.providerOrders)
  //       .where("authorID", isEqualTo: FireStoreUtils.getCurrentUid())
  //       .where("sectionId", isEqualTo: Constant.sectionConstantModel!.id.toString())
  //       .orderBy("createdAt", descending: true)
  //       .get()
  //       .then((value) {
  //         for (var element in value.docs) {
  //           OnProviderOrderModel orderModel = OnProviderOrderModel.fromJson(element.data());
  //           ordersList.add(orderModel);
  //         }
  //       });
  //   return ordersList;
  // }

  static Stream<List<OnProviderOrderModel>> getProviderOrdersStream() {
    return fireStore
        .collection(CollectionName.providerOrders)
        .where("authorID", isEqualTo: getCurrentUid())
        .where("sectionId", isEqualTo: Constant.sectionConstantModel!.id.toString())
        .orderBy("createdAt", descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => OnProviderOrderModel.fromJson(doc.data())).toList());
  }

  static Future<WorkerModel?> getWorker(String id) async {
    try {
      DocumentSnapshot<Map<String, dynamic>> doc = await fireStore.collection(CollectionName.providersWorkers).doc(id).get();

      if (doc.exists && doc.data() != null) {
        return WorkerModel.fromJson(doc.data()!);
      }
    } catch (e) {
      print("FireStoreUtils.getWorker error: $e");
    }
    return null;
  }

  static Future<OnProviderOrderModel?> getProviderOrderById(String orderId) async {
    OnProviderOrderModel? orderModel;
    await fireStore.collection(CollectionName.providerOrders).doc(orderId).get().then((value) {
      if (value.exists) {
        orderModel = OnProviderOrderModel.fromJson(value.data()!);
      }
    });
    return orderModel;
  }

  static Future<RatingModel?> getReviewsByProviderID(String orderId, String providerId) async {
    RatingModel? ratingModel;

    await fireStore
        .collection(CollectionName.itemsReview)
        .where('orderid', isEqualTo: orderId)
        .where('VendorId', isEqualTo: providerId)
        .limit(1)
        .get()
        .then((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            ratingModel = RatingModel.fromJson(snapshot.docs.first.data());
          }
        })
        .catchError((error) {
          print('Error fetching review for provider: $error');
        });

    return ratingModel;
  }

  static Future<RatingModel?> getReviewsByWorkerID(String orderId, String workerId) async {
    RatingModel? ratingModel;

    await fireStore
        .collection(CollectionName.itemsReview)
        .where('orderid', isEqualTo: orderId)
        .where('driverId', isEqualTo: workerId)
        .limit(1)
        .get()
        .then((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            ratingModel = RatingModel.fromJson(snapshot.docs.first.data());
          }
        })
        .catchError((error) {
          print('Error fetching review by worker ID: $error');
        });

    return ratingModel;
  }

  static Future<ProviderServiceModel?> getCurrentProvider(String uid) async {
    try {
      final doc = await fireStore.collection(CollectionName.providersServices).doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return ProviderServiceModel.fromJson(doc.data()!);
      }
    } catch (e, stackTrace) {
      print('Error fetching current provider: $e');
      print(stackTrace);
    }
    return null;
  }

  static Future<RatingModel?> updateReviewById(RatingModel ratingProduct) async {
    try {
      await fireStore.collection(CollectionName.itemsReview).doc(ratingProduct.id).set(ratingProduct.toJson());
      return ratingProduct;
    } catch (e, stackTrace) {
      print('Error updating review: $e');
      print(stackTrace);
      return null;
    }
  }

  static Future<ProviderServiceModel?> updateProvider(ProviderServiceModel provider) async {
    try {
      await fireStore.collection(CollectionName.providersServices).doc(provider.id).set(provider.toJson());
      return provider;
    } catch (e, stackTrace) {
      print('Error updating provider: $e');
      print(stackTrace);
      return null;
    }
  }

  static Future<WorkerModel?> updateWorker(WorkerModel worker) async {
    try {
      await fireStore.collection(CollectionName.providersWorkers).doc(worker.id).set(worker.toJson());
      return worker;
    } catch (e, stackTrace) {
      print('Error updating worker: $e');
      print(stackTrace);
      return null;
    }
  }

  static Future<ParcelOrderModel?> getParcelOrder(String orderId) async {
    try {
      final doc = await fireStore.collection(CollectionName.parcelOrders).doc(orderId).get();
      if (doc.exists && doc.data() != null) {
        return ParcelOrderModel.fromJson(doc.data()!);
      }
    } catch (e, stackTrace) {
      print('Error fetching current provider: $e');
      print(stackTrace);
    }
    return null;
  }

  static Stream<UserModel?> driverStream(String userId) {
    return fireStore.collection(CollectionName.users).doc(userId).snapshots().map((doc) {
      if (doc.data() != null) {
        return UserModel.fromJson(doc.data()!);
      }
      return null;
    });
  }

  static Future<void> updateCabOrder(CabOrderModel orderModel) async {
    if (orderModel.id!.isEmpty) {
      throw Exception("Order ID cannot be empty");
    }

    try {
      final docRef = fireStore.collection(CollectionName.rides).doc(orderModel.id);
      await docRef.set(orderModel.toJson(), SetOptions(merge: true));
    } catch (e) {
      print("Error updating OnDemand order: $e");
      rethrow;
    }
  }

  static Future<List<RentalVehicleType>> getRentalVehicleType() async {
    List<RentalVehicleType> vehicleTypeList = [];
    await fireStore.collection(CollectionName.rentalVehicleType).where('sectionId', isEqualTo: Constant.sectionConstantModel!.id).where("isActive", isEqualTo: true).get().then((value) {
      for (var element in value.docs) {
        try {
          RentalVehicleType category = RentalVehicleType.fromJson(element.data());
          vehicleTypeList.add(category);
        } catch (e, stackTrace) {
          print('getVehicleType error: ${element.id} $e');
          print(stackTrace);
        }
      }
    });
    return vehicleTypeList;
  }

  static Future<List<RentalPackageModel>> getRentalPackage(String vehicleId) async {
    List<RentalPackageModel> rentalPackageList = [];
    await fireStore.collection(CollectionName.rentalPackages).where("vehicleTypeId", isEqualTo: vehicleId).orderBy("ordering", descending: false).get().then((value) {
      for (var element in value.docs) {
        try {
          RentalPackageModel category = RentalPackageModel.fromJson(element.data());
          rentalPackageList.add(category);
        } catch (e, stackTrace) {
          print('getVehicleType error: ${element.id} $e');
          print(stackTrace);
        }
      }
    });
    return rentalPackageList;
  }

  static Stream<List<RentalOrderModel>> getRentalOrders() {
    return fireStore
        .collection(CollectionName.rentalOrders)
        .where('authorID', isEqualTo: FireStoreUtils.getCurrentUid())
        .where('sectionId', isEqualTo: Constant.sectionConstantModel!.id)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((query) {
          List<RentalOrderModel> ordersList = [];
          for (var element in query.docs) {
            ordersList.add(RentalOrderModel.fromJson(element.data()));
          }
          return ordersList;
        });
  }

  static Future<bool?> checkReferralCodeValidOrNot(String referralCode) async {
    bool? isExit;
    try {
      await fireStore.collection(CollectionName.referral).where("referralCode", isEqualTo: referralCode).get().then((value) {
        if (value.size > 0) {
          isExit = true;
        } else {
          isExit = false;
        }
      });
    } catch (e, s) {
      print('FireStoreUtils.firebaseCreateNewUser $e $s');
      return false;
    }
    return isExit;
  }

  static Future<RentalOrderModel?> getRentalOrderById(String orderId) async {
    RentalOrderModel? orderModel;
    await fireStore.collection(CollectionName.rentalOrders).doc(orderId).get().then((value) {
      if (value.exists) {
        orderModel = RentalOrderModel.fromJson(value.data()!);
      }
    });
    return orderModel;
  }

  static Future<RatingModel?> getReviewsbyID(String orderId) async {
    RatingModel? ratingModel;

    await fireStore
        .collection(CollectionName.itemsReview)
        .where('orderid', isEqualTo: orderId)
        .get()
        .then((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            ratingModel = RatingModel.fromJson(snapshot.docs.first.data());
          }
        })
        .catchError((error) {
          print('Error fetching review for provider: $error');
        });

    return ratingModel;
  }

  static Future<dynamic> getOrderByIdFromAllCollections(String orderId) async {
    final List<String> collections = [CollectionName.parcelOrders, CollectionName.rentalOrders, CollectionName.providerOrders, CollectionName.rides, CollectionName.vendorOrders];

    for (String collection in collections) {
      try {
        final snapshot = await fireStore.collection(collection).where('id', isEqualTo: orderId).limit(1).get();

        if (snapshot.docs.isNotEmpty) {
          final data = snapshot.docs.first.data();
          data['collection_name'] = collection;
          return data;
        }
      } catch (e) {
        log("Error fetching from $collection => $e");
      }
    }

    log("No order found with ID $orderId");
    return null;
  }

  static Future<void> setSos(String orderId, UserLocation userLocation) {
    DocumentReference documentReference = fireStore.collection(CollectionName.sos).doc();

    Map<String, dynamic> sosMap = {'id': documentReference.id, 'orderId': orderId, 'status': "Initiated", 'latLong': userLocation.toJson()};

    return documentReference
        .set(sosMap)
        .then((_) {
          print("SOS request created successfully for order: $orderId");
        })
        .catchError((error) {
          print("Failed to create SOS request: $error");
        });
  }

  static Future<bool> getSOS(String orderId) {
    return fireStore
        .collection(CollectionName.sos)
        .where('orderId', isEqualTo: orderId)
        .get()
        .then((querySnapshot) {
          bool isAdded = false;
          for (var element in querySnapshot.docs) {
            if (element['orderId'] == orderId) {
              isAdded = true;
              break;
            }
          }
          return isAdded;
        })
        .catchError((error) {
          print("Error checking SOS: $error");
          return false;
        });
  }

  static Future<void> setRideComplain({
    required String orderId,
    required String title,
    required String description,
    required String driverID,
    required String driverName,
    required String customerID,
    required String customerName,
  }) async {
    try {
      DocumentReference docRef = fireStore.collection(CollectionName.complaints).doc();

      Map<String, dynamic> complaintData = {
        'id': docRef.id,
        'createdAt': Timestamp.now(),
        'description': description,
        'driverId': driverID,
        'driverName': driverName,
        'orderId': orderId,
        'customerName': customerName,
        'customerId': customerID,
        'status': "Initiated",
        'title': title,
      };

      await docRef.set(complaintData);
    } catch (e) {
      print("Error adding ride complain: $e");
      rethrow;
    }
  }

  static Future<bool> isRideComplainAdded(String orderId) async {
    try {
      QuerySnapshot querySnapshot = await fireStore.collection(CollectionName.complaints).where('orderId', isEqualTo: orderId).limit(1).get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print("Error checking ride complain: $e");
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getRideComplainData(String orderId) async {
    try {
      QuerySnapshot querySnapshot = await fireStore.collection(CollectionName.complaints).where('orderId', isEqualTo: orderId).limit(1).get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.data() as Map<String, dynamic>;
      } else {
        return null;
      }
    } catch (e) {
      print("Error fetching ride complain data: $e");
      return null;
    }
  }

  static void removeFavouriteOndemandService(FavouriteOndemandServiceModel favouriteModel) {
    fireStore.collection(CollectionName.favoriteService).where("user_id", isEqualTo: favouriteModel.user_id).where("service_id", isEqualTo: favouriteModel.service_id).get().then((value) {
      for (var element in value.docs) {
        fireStore.collection(CollectionName.favoriteService).doc(element.id).delete().then((value) {
          print("Remove Success!");
        });
      }
    });
  }

  static Future<void> setFavouriteOndemandSection(FavouriteOndemandServiceModel favouriteModel) async {
    await fireStore.collection(CollectionName.favoriteService).add(favouriteModel.toJson()).then((value) {
      print("===FAVOURITE ADDED=== ${favouriteModel.toJson()}");
    });
  }

  static Future<List<FavouriteOndemandServiceModel>> getFavouritesServiceList(String userId) async {
    List<FavouriteOndemandServiceModel> lstFavourites = [];

    QuerySnapshot<Map<String, dynamic>> favourites =
        await fireStore.collection(CollectionName.favoriteService).where('user_id', isEqualTo: userId).where("section_id", isEqualTo: Constant.sectionConstantModel!.id).get();

    await Future.forEach(favourites.docs, (QueryDocumentSnapshot<Map<String, dynamic>> document) {
      try {
        lstFavourites.add(FavouriteOndemandServiceModel.fromJson(document.data()));
      } catch (e) {
        print('FavouriteModel.getCurrencys Parse error $e');
      }
    });

    return lstFavourites;
  }

  static Future<List<ProviderServiceModel>> getCurrentProviderService(FavouriteOndemandServiceModel model) async {
    List<ProviderServiceModel> providerService = [];

    QuerySnapshot<Map<String, dynamic>> reviewQuery =
        await fireStore.collection(CollectionName.providersServices).where('id', isEqualTo: model.service_id).where('sectionId', isEqualTo: model.section_id).get();
    await Future.forEach(reviewQuery.docs, (QueryDocumentSnapshot<Map<String, dynamic>> document) {
      try {
        providerService.add(ProviderServiceModel.fromJson(document.data()));
      } catch (e) {
        print('FireStoreUtils.getReviewByProviderServiceId Parse error ${document.id} $e');
      }
    });
    return providerService;
  }

  static StreamSubscription<QuerySnapshot>? adminChatSeenSubscription;

  static void setSeen() {
    final currentUserId = FireStoreUtils.getCurrentUid();

    adminChatSeenSubscription?.cancel();
    adminChatSeenSubscription = fireStore
        .collection(CollectionName.chat)
        .doc(currentUserId)
        .collection("thread")
        .where('senderId', isEqualTo: Constant.adminType)
        .where('seen', isEqualTo: false)
        .snapshots()
        .listen(
          (querySnapshot) async {
            for (final doc in querySnapshot.docs) {
              try {
                await doc.reference.update({'seen': true});
              } catch (e) {
                log(e.toString());
              }
            }
          },
          onError: (error) {
            log(error.toString());
          },
        );
  }

  static void stopSeenListener() {
    adminChatSeenSubscription?.cancel();
    adminChatSeenSubscription = null;
  }

  static StreamSubscription<QuerySnapshot>? orderChatSeenSubscription;

  static void setSeenChatForOrder({required String orderId}) {
    orderChatSeenSubscription?.cancel();
    orderChatSeenSubscription = fireStore
        .collection(CollectionName.chat)
        .doc(orderId)
        .collection("thread")
        .where('senderId', isNotEqualTo: FireStoreUtils.getCurrentUid())
        .where('seen', isEqualTo: false)
        .snapshots()
        .listen(
          (querySnapshot) async {
            for (final doc in querySnapshot.docs) {
              try {
                await doc.reference.update({'seen': true});
              } catch (e) {
                log(e.toString());
              }
            }
          },
          onError: (error) {
            log(error.toString());
          },
        );
  }

  static void stopSeenForOrderListener() {
    orderChatSeenSubscription?.cancel();
    orderChatSeenSubscription = null;
  }

  static Future<ConversationModel> addChat(ConversationModel conversationModel) async {
    final chatCollection = fireStore.collection(CollectionName.chat);
    final docId = (conversationModel.receiverId?.contains('admin') == false) ? conversationModel.orderId : conversationModel.senderId;
    await chatCollection.doc(docId).collection("thread").doc(conversationModel.id).set(conversationModel.toJson());
    return conversationModel;
  }

  static Future<InboxModel> addInbox(InboxModel inboxModel) async {
    final collection = fireStore.collection(CollectionName.chat);
    final docId = (inboxModel.senderReceiverId?.contains('admin') == false) ? inboxModel.orderId : inboxModel.senderId;
    await collection.doc(docId).set(inboxModel.toJson());
    return inboxModel;
  }
}
