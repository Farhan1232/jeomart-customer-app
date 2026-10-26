import 'dart:async';
import 'dart:developer';
import 'package:customer/constant/constant.dart';
import 'package:customer/models/cart_product_model.dart';
import 'package:customer/service/database_helper.dart';
import 'package:customer/themes/custom_dialog_box.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CartProvider with ChangeNotifier {
  final _cartStreamController = StreamController<List<CartProductModel>>.broadcast();
  List<CartProductModel> _cartItems = [];

  Stream<List<CartProductModel>> get cartStream => _cartStreamController.stream;

  CartProvider() {
    _initCart();
  }

  Future<void> _initCart() async {
    _cartItems = await DatabaseHelper.instance.fetchCartProducts();
    _cartStreamController.sink.add(_cartItems);
  }

  Future<void> addToCart(BuildContext context, CartProductModel product, int quantity) async {
    _cartItems = await DatabaseHelper.instance.fetchCartProducts();
    if ((_cartItems.where((item) => item.id == product.id)).isNotEmpty) {
      var index = _cartItems.indexWhere((item) => item.id == product.id);
      _cartItems[index].quantity = quantity;
      if (product.extras != null || product.extras!.isNotEmpty) {
        _cartItems[index].extras = product.extras;
        _cartItems[index].extrasPrice = product.extrasPrice;
      } else {
        _cartItems[index].extras = [];
        _cartItems[index].extrasPrice = "0";
      }
      await DatabaseHelper.instance.updateCartProduct(_cartItems[index]);
    } else {
      if (_cartItems.isEmpty || _cartItems.where((item) => item.vendorID == product.vendorID).isNotEmpty) {
        product.quantity = quantity;
        _cartItems.add(product);
        cartItem.add(product);
        await DatabaseHelper.instance.insertCartProduct(product);
        log("===> insert");
      } else {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return CustomDialogBox(
              title: "Alert".tr,
              descriptions: "Your cart already contains items from another restaurant. Would you like to replace them with items from this restaurant instead?".tr,
              positiveString: "Add".tr,
              negativeString: "Cancel".tr,
              positiveClick: () async {
                cartItem.clear();
                _cartItems.clear();
                DatabaseHelper.instance.deleteAllCartProducts();
                addToCart(context, product, quantity);
                Get.back();
              },
              negativeClick: () {
                Get.back();
              },
              img: null,
            );
          },
        );
      }
    }
    _initCart();
  }

  Future<void> removeFromCart(CartProductModel product, int quantity) async {
    _cartItems = await DatabaseHelper.instance.fetchCartProducts();
    var index = _cartItems.indexWhere((item) => item.id == product.id);
    if (index >= 0) {
      _cartItems[index].quantity = quantity;
      if (_cartItems[index].quantity == 0) {
        await DatabaseHelper.instance.deleteCartProduct(product.id!);
        _cartItems.removeAt(index);
        cartItem.removeAt(index);
      } else {
        await DatabaseHelper.instance.updateCartProduct(_cartItems[index]);
      }
    }
    _initCart();
  }

  Future<void> clearDatabase() async {
    _cartItems.clear();
    cartItem.clear();
    _cartStreamController.sink.add(_cartItems);
  }
}
