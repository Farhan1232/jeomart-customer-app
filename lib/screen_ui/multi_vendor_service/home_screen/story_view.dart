import 'package:customer/constant/constant.dart';
import 'package:customer/models/story_model.dart';
import 'package:customer/models/vendor_model.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:customer/utils/network_image_widget.dart';
import 'package:customer/widget/story_view/controller/story_controller.dart';
import 'package:customer/widget/story_view/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import '../../../service/fire_store_utils.dart';
import '../../../widget/story_view/widgets/story_view.dart';
import '../restaurant_details_screen/restaurant_details_screen.dart';

// ignore: must_be_immutable
class MoreStories extends StatefulWidget {
  final List<StoryModel> storyList;
  int index;

  MoreStories({super.key, required this.index, required this.storyList});

  @override
  MoreStoriesState createState() => MoreStoriesState();
}

class MoreStoriesState extends State<MoreStories> {
  StoryController storyController = StoryController();

  @override
  void dispose() {
    storyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          // Swipe to next story
          if (details.primaryVelocity != null && details.primaryVelocity! < 0) {
            if (widget.index < widget.storyList.length - 1) {
              setState(() {
                storyController.dispose();
                storyController = StoryController();
              });
              setState(() {
                widget.index++;
              });
            } else {
              Navigator.pop(context);
            }
          }

          // Swipe to previous story
          if (details.primaryVelocity != null && details.primaryVelocity! > 0) {
            if (widget.index > 0) {
              setState(() {
                storyController.dispose();
                storyController = StoryController();
              });
              setState(() {
                widget.index--;
              });
            }
          }
        },
        child: Stack(
          children: [
            StoryView(
              key: ValueKey(widget.index),
              storyItems:
                  List.generate(widget.storyList[widget.index].videoUrl.length, (i) {
                    return StoryItem.pageVideo(widget.storyList[widget.index].videoUrl[i], controller: storyController);
                  }).toList(),
              onComplete: () {
                debugPrint("--------->");
                debugPrint(widget.storyList.length.toString());
                debugPrint(widget.index.toString());
                if (widget.storyList.length - 1 != widget.index) {
                  setState(() {
                    widget.index = widget.index + 1;
                  });
                } else {
                  Navigator.pop(context);
                }
              },
              progressPosition: ProgressPosition.top,
              repeat: true,
              controller: storyController,
              onVerticalSwipeComplete: (direction) {
                if (direction == Direction.down) {
                  Navigator.pop(context);
                }
              },
            ),
            Padding(
              padding: EdgeInsets.only(top: MediaQuery.of(context).viewPadding.top + 30, left: 16, right: 16),
              child: FutureBuilder(
                future: FireStoreUtils.getVendorById(widget.storyList[widget.index].vendorID.toString()),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return SizedBox();
                  } else {
                    if (snapshot.hasError) {
                      return Center(child: Text('${"Error".tr}: ${snapshot.error}'));
                    } else if (snapshot.data == null) {
                      return const SizedBox();
                    } else {
                      VendorModel vendorModel = snapshot.data!;
                      return InkWell(
                        onTap: () {
                          Get.to(const RestaurantDetailsScreen(), arguments: {"vendorModel": vendorModel});
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipOval(child: NetworkImageWidget(imageUrl: vendorModel.photo.toString(), width: 50, height: 50, fit: BoxFit.cover)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    vendorModel.title.toString(),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    style: const TextStyle(color: Colors.white, fontSize: 16, overflow: TextOverflow.ellipsis, fontWeight: FontWeight.w700),
                                  ),
                                  Row(
                                    children: [
                                      SvgPicture.asset("assets/icons/ic_star.svg"),
                                      const SizedBox(width: 5),
                                      Text(
                                        "${Constant.calculateReview(reviewCount: vendorModel.reviewsCount.toString(), reviewSum: vendorModel.reviewsSum.toString())} ${'reviews'.tr}",
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        style: const TextStyle(color: AppThemeData.warning300, fontSize: 12, overflow: TextOverflow.ellipsis, fontWeight: FontWeight.w700),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: () async {
                                Get.back();
                              },
                              child: Container(
                                padding: const EdgeInsets.all(10.0),
                                decoration: BoxDecoration(borderRadius: BorderRadius.circular(30), color: Colors.grey),
                                child: SvgPicture.asset("assets/icons/ic_close.svg", colorFilter: ColorFilter.mode(AppThemeData.grey800, BlendMode.srcIn)),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
