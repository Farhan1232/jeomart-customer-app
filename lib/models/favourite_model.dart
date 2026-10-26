class FavouriteModel {
  String? restaurantId;
  String? userId;
  String? sectionId;

  FavouriteModel({this.restaurantId, this.userId,this.sectionId});

  factory FavouriteModel.fromJson(Map<String, dynamic> parsedJson) {
    return FavouriteModel(restaurantId: parsedJson["store_id"] ?? "", userId: parsedJson["user_id"] ?? "",sectionId: parsedJson["section_id"] ?? "");
  }

  Map<String, dynamic> toJson() {
    return {"store_id": restaurantId, "user_id": userId, "section_id": sectionId};
  }
}
