class EmailTemplateModel {
  String? id;
  String? type;
  String? message;
  String? subject;
  bool? isSendToAdmin;

  EmailTemplateModel({this.subject, this.id, this.type, this.message, this.isSendToAdmin});

  EmailTemplateModel.fromJson(Map<String, dynamic> json) {
    subject = json['subject'];
    id = json['id'];
    type = json['type'];
    message = json['message'];
    isSendToAdmin = json['isSendToAdmin'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['subject'] = subject;
    data['id'] = id;
    data['type'] = type;
    data['message'] = message;
    data['isSendToAdmin'] = isSendToAdmin;
    return data;
  }
}
