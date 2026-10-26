class OrangeMoney {
  String? image;
  String? clientId;
  String? auth;
  bool? enable;
  String? name;
  String? notifyUrl;
  String? clientSecret;
  bool? isSandbox;
  String? returnUrl;
  String? merchantKey;
  String? cancelUrl;
  String? notifUrl;

  OrangeMoney(
      {this.image,
      this.clientId,
      this.auth,
      this.enable,
      this.name,
      this.notifyUrl,
      this.clientSecret,
      this.isSandbox,
      this.returnUrl,
      this.cancelUrl,
      this.notifUrl,
      this.merchantKey});

  OrangeMoney.fromJson(Map<String, dynamic> json) {
    image = json['image'];
    clientId = json['clientId'];
    auth = json['auth'];
    enable = json['enable'];
    name = json['name'];
    notifyUrl = json['notifyUrl'];
    clientSecret = json['clientSecret'];
    isSandbox = json['isSandbox'];
    returnUrl = json['returnUrl'];
    merchantKey = json['merchantKey'];
    cancelUrl = json['cancelUrl'];
    notifUrl = json['notifUrl'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['image'] = image;
    data['clientId'] = clientId;
    data['auth'] = auth;
    data['enable'] = enable;
    data['name'] = name;
    data['notifyUrl'] = notifyUrl;
    data['clientSecret'] = clientSecret;
    data['isSandbox'] = isSandbox;
    data['returnUrl'] = returnUrl;
    data['merchantKey'] = merchantKey;
    data['cancelUrl'] = cancelUrl;
    data['notifUrl'] = notifUrl;
    return data;
  }
}
