class FavouriteOndemandServiceModel {
  String? serviceAuthorId;
  String? service_id;
  String? user_id;
  String? section_id;

  FavouriteOndemandServiceModel({this.service_id, this.serviceAuthorId, this.user_id, this.section_id});

  factory FavouriteOndemandServiceModel.fromJson(Map<String, dynamic> parsedJson) {
    return FavouriteOndemandServiceModel(
        serviceAuthorId: parsedJson["service_author_id"] ?? "",
        section_id: parsedJson["section_id"] ?? "",
        user_id: parsedJson["user_id"] ?? "",
        service_id: parsedJson["service_id"] ?? "");
  }

  Map<String, dynamic> toJson() {
    return {"service_author_id": serviceAuthorId, "section_id": section_id, "user_id": user_id, "service_id": service_id};
  }
}
