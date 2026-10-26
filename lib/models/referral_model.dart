class ReferralModel {
  String? id;
  String? referralCode;
  String? referralBy;

  ReferralModel({this.id,this.referralCode, this.referralBy});

  ReferralModel.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    referralCode = json['referralCode'];
    referralBy = json['referralBy'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['referralCode'] = referralCode;
    data['referralBy'] = referralBy;
    return data;
  }
}
