class Xendit {
  bool? enable;
  String? name;
  bool? isSandbox;
  String? apiKey;
  String? image;

  Xendit({
    this.name,
    this.enable,
    this.apiKey,
    this.isSandbox,
    this.image,
  });

  Xendit.fromJson(Map<String, dynamic> json) {
    enable = json['enable'];
    name = json['name'];
    isSandbox = json['isSandbox'];
    apiKey = json['apiKey'];
    image = json['image'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};

    data['enable'] = enable;
    data['name'] = name;
    data['isSandbox'] = isSandbox;
    data['apiKey'] = apiKey;
    data['image'] = image;
    return data;
  }
}
