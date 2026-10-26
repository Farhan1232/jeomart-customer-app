class FlutterWaveModel {
  bool? isSandbox;
  bool? isWithdrawEnabled;
  String? publicKey;
  String? encryptionKey;
  bool? isEnable;
  String? secretKey;

  FlutterWaveModel({this.isSandbox, this.isWithdrawEnabled, this.publicKey, this.encryptionKey, this.isEnable, this.secretKey});

  FlutterWaveModel.fromJson(Map<String, dynamic> json) {
    isSandbox = json['isSandbox'];
    isWithdrawEnabled = json['isWithdrawEnabled'];
    publicKey = json['publicKey'];
    encryptionKey = json['encryptionKey'];
    isEnable = json['isEnable'];
    secretKey = json['secretKey'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['isSandbox'] = isSandbox;
    data['isWithdrawEnabled'] = isWithdrawEnabled;
    data['publicKey'] = publicKey;
    data['encryptionKey'] = encryptionKey;
    data['isEnable'] = isEnable;
    data['secretKey'] = secretKey;
    return data;
  }
}
