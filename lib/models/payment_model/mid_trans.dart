class MidTrans {
  bool? enable;
  String? name;
  bool? isSandbox;
  String? serverKey;
  String? image;

  MidTrans({
    this.name,
    this.enable,
    this.serverKey,
    this.isSandbox,
    this.image,
  });

  MidTrans.fromJson(Map<String, dynamic> json) {
    enable = json['enable'];
    name = json['name'];
    isSandbox = json['isSandbox'];
    serverKey = json['serverKey'];
    image = json['image'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};

    data['enable'] = enable;
    data['name'] = name;
    data['isSandbox'] = isSandbox;
    data['serverKey'] = serverKey;
    data['image'] = image;
    return data;
  }
}
