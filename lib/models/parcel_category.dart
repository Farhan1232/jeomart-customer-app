class ParcelCategory {
  String? image;
  int? setOrder;
  bool? publish;
  String? id;
  String? title;

  ParcelCategory({this.image, this.setOrder, this.publish, this.id, this.title});

  ParcelCategory.fromJson(Map<String, dynamic> json) {
    image = json['image'];
    setOrder = json['set_order'];
    publish = json['publish'];
    id = json['id'];
    title = json['title'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['image'] = image;
    data['set_order'] = setOrder;
    data['publish'] = publish;
    data['id'] = id;
    data['title'] = title;
    return data;
  }
}
