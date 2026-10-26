class PayFastModel {
  String? returnUrl;
  String? cancelUrl;
  String? notifyUrl;
  String? merchantKey;
  bool? isEnable;
  String? merchantId;
  bool? isSandbox;

  PayFastModel({this.returnUrl, this.cancelUrl, this.notifyUrl, this.merchantKey, this.isEnable, this.merchantId, this.isSandbox});

  PayFastModel.fromJson(Map<String, dynamic> json) {
    returnUrl = json['return_url'];
    cancelUrl = json['cancel_url'];
    notifyUrl = json['notify_url'];
    merchantKey = json['merchant_key'];
    isEnable = json['isEnable'];
    merchantId = json['merchant_id'];
    isSandbox = json['isSandbox'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['return_url'] = returnUrl;
    data['cancel_url'] = cancelUrl;
    data['notify_url'] = notifyUrl;
    data['merchant_key'] = merchantKey;
    data['isEnable'] = isEnable;
    data['merchant_id'] = merchantId;
    data['isSandbox'] = isSandbox;
    return data;
  }
}
