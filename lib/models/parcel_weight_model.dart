class ParcelWeightModel {
  String? deliveryCharge;
  String? id;
  String? title;

  ParcelWeightModel({this.deliveryCharge, this.id, this.title});

  ParcelWeightModel.fromJson(Map<String, dynamic> json) {
    deliveryCharge = json['delivery_charge'];
    id = json['id'];
    title = json['title'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['delivery_charge'] = deliveryCharge;
    data['id'] = id;
    data['title'] = title;
    return data;
  }
}
