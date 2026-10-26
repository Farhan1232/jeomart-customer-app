class WalletSettingModel {
  bool? isEnabled;

  WalletSettingModel({this.isEnabled});

  WalletSettingModel.fromJson(Map<String, dynamic> json) {
    isEnabled = json['isEnabled'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['isEnabled'] = isEnabled;
    return data;
  }
}
