class PlatformFeeModel {
  String? fee;
  bool? enable;

  PlatformFeeModel({this.fee, this.enable});

  PlatformFeeModel.fromJson(Map<String, dynamic> json) {
    fee = json['fee'] ?? '0.0';
    enable = json['enable'] ?? false;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['fee'] = fee;
    data['enable'] = enable;
    return data;
  }
}
