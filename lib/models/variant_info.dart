class VariantInfo {
  String? variantId;
  String? variantPrice;
  String? variantSku;
  String? variant_image;
  Map<String, dynamic>? variant_options;

  VariantInfo({this.variantId, this.variantPrice, this.variant_image, this.variantSku, this.variant_options});

  VariantInfo.fromJson(Map<String, dynamic> json) {
    variantId = json['variantId'] ?? '';
    variantPrice = json['variantPrice'] ?? '';
    variantSku = json['variantSku'] ?? '';
    variant_image = json['variant_image'] ?? '';
    variant_options = json['variant_options'] ?? {};
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['variantId'] = variantId;
    data['variantPrice'] = variantPrice;
    data['variantSku'] = variantSku;
    data['variant_image'] = variant_image;
    data['variant_options'] = variant_options;
    return data;
  }
}
