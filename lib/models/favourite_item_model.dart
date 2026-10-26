class FavouriteItemModel {
  String? storeId;
  String? userId;
  String? productId;
  String? sectionId;

  FavouriteItemModel({this.storeId, this.userId, this.productId, this.sectionId});

  factory FavouriteItemModel.fromJson(Map<String, dynamic> parsedJson) {
    return FavouriteItemModel(
      storeId: parsedJson["store_id"] ?? "",
      userId: parsedJson["user_id"] ?? "",
      productId: parsedJson["product_id"] ?? "",
      sectionId: parsedJson["section_id"] ?? "",
    );
  }

  Map<String, dynamic> toJson() {
    return {"store_id": storeId, "user_id": userId, "product_id": productId, "section_id": sectionId};
  }
}
