class BannerModel {
  String? id;
  int? setOrder;
  String? position;
  String? sectionId;
  String? photo;
  String? title;
  String? redirect_type;
  String? redirect_id;
  bool? isPublish;

  BannerModel({this.id, this.setOrder, this.position, this.redirect_type, this.redirect_id, this.sectionId, this.photo, this.title, this.isPublish});

  BannerModel.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    position = json['position'];
    sectionId = json['sectionId'];
    setOrder = json['set_order'];
    photo = json['photo'];
    title = json['title'];
    isPublish = json['is_publish'];
    redirect_type = json['redirect_type'];
    redirect_id = json['redirect_id'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['position'] = position;
    data['sectionId'] = sectionId;
    data['set_order'] = setOrder;
    data['photo'] = photo;
    data['title'] = title;
    data['is_publish'] = isPublish;
    data['redirect_type'] = redirect_type;
    data['redirect_id'] = redirect_id;
    return data;
  }
}
