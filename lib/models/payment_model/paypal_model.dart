class PayPalModel {
  String? paypalSecret;
  bool? isWithdrawEnabled;
  String? paypalAppId;
  bool? isEnabled;
  bool? isLive;
  String? paypalClient;

  PayPalModel({this.paypalSecret, this.isWithdrawEnabled, this.paypalAppId, this.isEnabled, this.isLive, this.paypalClient});

  PayPalModel.fromJson(Map<String, dynamic> json) {
    paypalSecret = json['paypalSecret'];
    isWithdrawEnabled = json['isWithdrawEnabled'];
    paypalAppId = json['paypalAppId'];
    isEnabled = json['isEnabled'];
    isLive = json['isLive'];
    paypalClient = json['paypalClient'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['paypalSecret'] = paypalSecret;
    data['isWithdrawEnabled'] = isWithdrawEnabled;
    data['paypalAppId'] = paypalAppId;
    data['isEnabled'] = isEnabled;
    data['isLive'] = isLive;
    data['paypalClient'] = paypalClient;
    return data;
  }
}
