class StripeModel {
  String? stripeSecret;
  String? clientpublishableKey;
  bool? isWithdrawEnabled;
  bool? isEnabled;
  bool? isSandboxEnabled;
  String? stripeKey;

  StripeModel({this.stripeSecret, this.clientpublishableKey, this.isWithdrawEnabled, this.isEnabled, this.isSandboxEnabled, this.stripeKey});

  StripeModel.fromJson(Map<String, dynamic> json) {
    stripeSecret = json['stripeSecret'];
    clientpublishableKey = json['clientpublishableKey'];
    isWithdrawEnabled = json['isWithdrawEnabled'];
    isEnabled = json['isEnabled'];
    isSandboxEnabled = json['isSandboxEnabled'];
    stripeKey = json['stripeKey'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['stripeSecret'] = stripeSecret;
    data['clientpublishableKey'] = clientpublishableKey;
    data['isWithdrawEnabled'] = isWithdrawEnabled;
    data['isEnabled'] = isEnabled;
    data['isSandboxEnabled'] = isSandboxEnabled;
    data['stripeKey'] = stripeKey;
    return data;
  }
}
