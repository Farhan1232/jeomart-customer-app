class OnBoardingModel {
  String? description;
  String? id;
  String? title;
  String? image;

  OnBoardingModel({this.description, this.id, this.title, this.image});

  OnBoardingModel.fromJson(Map<String, dynamic> json) {
    description = json['description'];
    id = json['id'];
    title = json['title'];
    image = json['image'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['description'] = description;
    data['id'] = id;
    data['title'] = title;
    data['image'] = image;
    return data;
  }
}
