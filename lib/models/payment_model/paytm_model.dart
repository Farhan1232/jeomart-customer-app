class PaytmModel {
  String? paytmMID;
  String? pAYTMMERCHANTKEY;
  bool? isEnabled;
  bool? isSandboxEnabled;

  PaytmModel({this.paytmMID, this.pAYTMMERCHANTKEY, this.isEnabled, this.isSandboxEnabled});

  PaytmModel.fromJson(Map<String, dynamic> json) {
    paytmMID = json['PaytmMID'];
    pAYTMMERCHANTKEY = json['PAYTM_MERCHANT_KEY'];
    isEnabled = json['isEnabled'];
    isSandboxEnabled = json['isSandboxEnabled'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['PaytmMID'] = paytmMID;
    data['PAYTM_MERCHANT_KEY'] = pAYTMMERCHANTKEY;
    data['isEnabled'] = isEnabled;
    data['isSandboxEnabled'] = isSandboxEnabled;
    return data;
  }
}
