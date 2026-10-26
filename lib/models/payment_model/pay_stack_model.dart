class PayStackModel {
  bool? isSandbox;
  String? callbackURL;
  String? publicKey;
  String? secretKey;
  bool? isEnable;
  String? webhookURL;

  PayStackModel({this.isSandbox, this.callbackURL, this.publicKey, this.secretKey, this.isEnable, this.webhookURL});

  PayStackModel.fromJson(Map<String, dynamic> json) {
    isSandbox = json['isSandbox'];
    callbackURL = json['callbackURL'];
    publicKey = json['publicKey'];
    secretKey = json['secretKey'];
    isEnable = json['isEnable'];
    webhookURL = json['webhookURL'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['isSandbox'] = isSandbox;
    data['callbackURL'] = callbackURL;
    data['publicKey'] = publicKey;
    data['secretKey'] = secretKey;
    data['isEnable'] = isEnable;
    data['webhookURL'] = webhookURL;
    return data;
  }
}
