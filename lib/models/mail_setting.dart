class MailSettings {
  String? emailSetting;
  String? fromName;
  String? host;
  String? mailEncryptionType;
  String? mailMethod;
  String? password;
  String? port;
  String? userName;

  MailSettings(
      {this.emailSetting,
        this.fromName,
        this.host,
        this.mailEncryptionType,
        this.mailMethod,
        this.password,
        this.port,
        this.userName});

  MailSettings.fromJson(Map<String, dynamic> json) {
    emailSetting = json['emailSetting'];
    fromName = json['fromName'];
    host = json['host'];
    mailEncryptionType = json['mailEncryptionType'];
    mailMethod = json['mailMethod'];
    password = json['password'];
    port = json['port'];
    userName = json['userName'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['emailSetting'] = emailSetting;
    data['fromName'] = fromName;
    data['host'] = host;
    data['mailEncryptionType'] = mailEncryptionType;
    data['mailMethod'] = mailMethod;
    data['password'] = password;
    data['port'] = port;
    data['userName'] = userName;
    return data;
  }
}
