import 'dart:async';

import 'package:customer/models/vendor_model.dart';
import 'package:customer/themes/responsive.dart';
import 'package:customer/utils/network_image_widget.dart';
import 'package:flutter/material.dart';

class RestaurantImageView extends StatefulWidget {
  final VendorModel vendorModel;

  const RestaurantImageView({super.key, required this.vendorModel});

  @override
  State<RestaurantImageView> createState() => _RestaurantImageViewState();
}

class _RestaurantImageViewState extends State<RestaurantImageView> {
  int currentPage = 0;

  PageController pageController = PageController(initialPage: 1);

  /// The slide timer. It used to be started and never kept, so it ran for the
  /// rest of the session after the card was gone - one more for every store
  /// card ever built, including each time a card scrolled back into view.
  Timer? _slideTimer;

  @override
  void initState() {
    animateSlider();
    super.initState();
  }

  @override
  void dispose() {
    _slideTimer?.cancel();
    pageController.dispose();
    super.dispose();
  }

  void animateSlider() {
    if (widget.vendorModel.photos != null && widget.vendorModel.photos!.isNotEmpty) {
      if (widget.vendorModel.photos!.length > 1) {
        _slideTimer = Timer.periodic(const Duration(seconds: 2), (Timer timer) {
          if (currentPage < widget.vendorModel.photos!.length - 1) {
            currentPage++;
          } else {
            currentPage = 0;
          }

          if (pageController.hasClients) {
            pageController.animateToPage(
              currentPage,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeIn,
            );
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: Responsive.height(20, context),
      child: widget.vendorModel.photos == null || widget.vendorModel.photos!.isEmpty
          ? NetworkImageWidget(
              imageUrl: widget.vendorModel.photo.toString(),
              fit: BoxFit.cover,
              height: Responsive.height(20, context),
              width: Responsive.width(100, context),
            )
          : PageView.builder(
              physics: const BouncingScrollPhysics(),
              controller: pageController,
              scrollDirection: Axis.horizontal,
              allowImplicitScrolling: true,
              itemCount: widget.vendorModel.photos!.length,
              padEnds: false,
              pageSnapping: true,
              itemBuilder: (BuildContext context, int index) {
                String image = widget.vendorModel.photos![index];
                return NetworkImageWidget(
                  imageUrl: image.toString(),
                  fit: BoxFit.cover,
                  height: Responsive.height(20, context),
                  width: Responsive.width(100, context),
                );
              },
            ),
    );
  }
}
