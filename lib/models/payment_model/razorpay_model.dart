class RazorPayModel {
  String? razorpaySecret;
  bool? isWithdrawEnabled;
  bool? isSandboxEnabled;
  bool? isEnabled;
  String? razorpayKey;

  RazorPayModel({this.razorpaySecret, this.isWithdrawEnabled, this.isSandboxEnabled, this.isEnabled, this.razorpayKey});

  RazorPayModel.fromJson(Map<String, dynamic> json) {
    razorpaySecret = json['razorpaySecret'];
    isWithdrawEnabled = json['isWithdrawEnabled'];
    isSandboxEnabled = json['isSandboxEnabled'];
    isEnabled = json['isEnabled'];
    razorpayKey = json['razorpayKey'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['razorpaySecret'] = razorpaySecret;
    data['isWithdrawEnabled'] = isWithdrawEnabled;
    data['isSandboxEnabled'] = isSandboxEnabled;
    data['isEnabled'] = isEnabled;
    data['razorpayKey'] = razorpayKey;
    return data;
  }
}
