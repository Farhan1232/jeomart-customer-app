class TaxModel {
  String? country;
  bool? enable;
  String? tax;
  String? id;
  String? type;
  String? title;
  String? scope;
  String? sectionId;

  TaxModel({
    this.country,
    this.enable,
    this.tax,
    this.id,
    this.type,
    this.title,
    this.scope,
    this.sectionId,
  });

  TaxModel.fromJson(Map<String, dynamic> json) {
    country = json['country'];
    enable = json['enable'].toString().toLowerCase() == 'true' ? true : false;
    tax = json['tax'];
    id = json['id'];
    type = json['type'];
    title = json['title'];
    scope = json['scope'];
    sectionId = json['sectionId'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['country'] = country;
    data['enable'] = enable;
    data['tax'] = tax;
    data['id'] = id;
    data['type'] = type;
    data['title'] = title;
    data['scope'] = scope;
    data['sectionId'] = sectionId;
    return data;
  }
}
