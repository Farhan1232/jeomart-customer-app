class PopularDestination {
  String? image;
  String? id;
  String? title;
  double? latitude;
  double? longitude;

  PopularDestination(
      {this.image, this.id, this.title, this.latitude, this.longitude});

  PopularDestination.fromJson(Map<String, dynamic> json) {
    image = json['image'];
    id = json['id'];
    title = json['title'];
    latitude = json['latitude'];
    longitude = json['longitude'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['image'] = image;
    data['id'] = id;
    data['title'] = title;
    data['latitude'] = latitude;
    data['longitude'] = longitude;
    return data;
  }
}
