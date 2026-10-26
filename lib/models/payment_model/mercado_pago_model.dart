class MercadoPagoModel {
  bool? isSandboxEnabled;
  bool? isEnabled;
  String? accessToken;
  String? publicKey;

  MercadoPagoModel({this.isSandboxEnabled, this.isEnabled, this.accessToken, this.publicKey});

  MercadoPagoModel.fromJson(Map<String, dynamic> json) {
    isSandboxEnabled = json['isSandboxEnabled'];
    isEnabled = json['isEnabled'];
    accessToken = json['AccessToken'];
    publicKey = json['PublicKey'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['isSandboxEnabled'] = isSandboxEnabled;
    data['isEnabled'] = isEnabled;
    data['AccessToken'] = accessToken;
    data['PublicKey'] = publicKey;
    return data;
  }
}
