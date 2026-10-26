class BrandsModel {
  String? photo;
  String? sectionId;
  String? id;
  String? title;
  bool? isPublish;

  BrandsModel({this.photo, this.sectionId, this.id, this.title, this.isPublish});

  BrandsModel.fromJson(Map<String, dynamic> json) {
    photo = json['photo'];
    sectionId = json['sectionId'];
    id = json['id'];
    title = json['title'];
    isPublish = json['is_publish'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['photo'] = photo;
    data['sectionId'] = sectionId;
    data['id'] = id;
    data['title'] = title;
    data['is_publish'] = isPublish;
    return data;
  }
}
