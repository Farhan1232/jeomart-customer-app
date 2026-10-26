class AdminCommission {
  String? amount;
  bool? isEnabled;
  String? commissionType;

  AdminCommission({this.amount, this.isEnabled, this.commissionType});

  AdminCommission.fromJson(Map<String, dynamic> json) {
    amount = json['commission'].toString();
    isEnabled = json['enable'];
    commissionType = json['type'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['commission'] = amount;
    data['enable'] = isEnabled;
    data['type'] = commissionType;
    return data;
  }
}
