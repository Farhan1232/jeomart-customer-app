class CategoryModel {
  String? id;
  String? title;
  String? image;
  bool? publish;

  CategoryModel({this.id, this.title, this.image, this.publish});

  CategoryModel.fromJson(Map<String, dynamic> json) {
    id = json['id'] ?? '';
    title = json['title'] ?? '';
    image = json['image'] ?? '';
    publish = json['publish'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['title'] = title;
    data['image'] = image;
    data['publish'] = publish;
    return data;
  }
}
