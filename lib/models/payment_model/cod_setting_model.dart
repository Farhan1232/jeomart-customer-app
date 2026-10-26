class CodSettingModel {
  bool? isEnabled;

  CodSettingModel({this.isEnabled});

  CodSettingModel.fromJson(Map<String, dynamic> json) {
    isEnabled = json['isEnabled'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['isEnabled'] = isEnabled;
    return data;
  }
}
