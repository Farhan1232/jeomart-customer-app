class LanguageModel {
  bool? isActive;
  String? slug;
  String? title;
  String? image;
  bool? isRtl;

  LanguageModel({this.isActive, this.slug, this.title, this.isRtl, this.image});

  LanguageModel.fromJson(Map<String, dynamic> json) {
    isActive = json['isActive'];
    slug = json['slug'];
    title = json['title'];
    isRtl = json['is_rtl'];
    image = json['image'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['isActive'] = isActive;
    data['slug'] = slug;
    data['title'] = title;
    data['is_rtl'] = isRtl;
    data['image'] = image;
    return data;
  }
}
