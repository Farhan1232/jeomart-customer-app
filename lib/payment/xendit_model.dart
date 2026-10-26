class XenditModel {
  String? id;
  String? externalId;
  String? userId;
  String? status;
  String? merchantName;
  String? merchantProfilePictureUrl;
  int? amount;
  String? payerEmail;
  String? description;
  String? expiryDate;
  String? invoiceUrl;
  List<AvailableBanks>? availableBanks;
  List<AvailableRetailOutlets>? availableRetailOutlets;
  List<AvailableEwallets>? availableEwallets;
  List<AvailableQrCodes>? availableQrCodes;
  List<AvailableDirectDebits>? availableDirectDebits;
  List<AvailablePaylaters>? availablePaylaters;
  bool? shouldExcludeCreditCard;
  bool? shouldSendEmail;
  String? created;
  String? updated;
  String? currency;
  Null metadata;

  XenditModel(
      {this.id,
      this.externalId,
      this.userId,
      this.status,
      this.merchantName,
      this.merchantProfilePictureUrl,
      this.amount,
      this.payerEmail,
      this.description,
      this.expiryDate,
      this.invoiceUrl,
      this.availableBanks,
      this.availableRetailOutlets,
      this.availableEwallets,
      this.availableQrCodes,
      this.availableDirectDebits,
      this.availablePaylaters,
      this.shouldExcludeCreditCard,
      this.shouldSendEmail,
      this.created,
      this.updated,
      this.currency,
      this.metadata});

  XenditModel.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    externalId = json['external_id'];
    userId = json['user_id'];
    status = json['status'];
    merchantName = json['merchant_name'];
    merchantProfilePictureUrl = json['merchant_profile_picture_url'];
    amount = json['amount'];
    payerEmail = json['payer_email'];
    description = json['description'];
    expiryDate = json['expiry_date'];
    invoiceUrl = json['invoice_url'];
    if (json['available_banks'] != null) {
      availableBanks = <AvailableBanks>[];
      json['available_banks'].forEach((v) {
        availableBanks!.add(AvailableBanks.fromJson(v));
      });
    }
    if (json['available_retail_outlets'] != null) {
      availableRetailOutlets = <AvailableRetailOutlets>[];
      json['available_retail_outlets'].forEach((v) {
        availableRetailOutlets!.add(AvailableRetailOutlets.fromJson(v));
      });
    }
    if (json['available_ewallets'] != null) {
      availableEwallets = <AvailableEwallets>[];
      json['available_ewallets'].forEach((v) {
        availableEwallets!.add(AvailableEwallets.fromJson(v));
      });
    }
    if (json['available_qr_codes'] != null) {
      availableQrCodes = <AvailableQrCodes>[];
      json['available_qr_codes'].forEach((v) {
        availableQrCodes!.add(AvailableQrCodes.fromJson(v));
      });
    }
    if (json['available_direct_debits'] != null) {
      availableDirectDebits = <AvailableDirectDebits>[];
      json['available_direct_debits'].forEach((v) {
        availableDirectDebits!.add(AvailableDirectDebits.fromJson(v));
      });
    }
    if (json['available_paylaters'] != null) {
      availablePaylaters = <AvailablePaylaters>[];
      json['available_paylaters'].forEach((v) {
        availablePaylaters!.add(AvailablePaylaters.fromJson(v));
      });
    }
    shouldExcludeCreditCard = json['should_exclude_credit_card'];
    shouldSendEmail = json['should_send_email'];
    created = json['created'];
    updated = json['updated'];
    currency = json['currency'];
    metadata = json['metadata'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['external_id'] = externalId;
    data['user_id'] = userId;
    data['status'] = status;
    data['merchant_name'] = merchantName;
    data['merchant_profile_picture_url'] = merchantProfilePictureUrl;
    data['amount'] = amount;
    data['payer_email'] = payerEmail;
    data['description'] = description;
    data['expiry_date'] = expiryDate;
    data['invoice_url'] = invoiceUrl;
    if (availableBanks != null) {
      data['available_banks'] = availableBanks!.map((v) => v.toJson()).toList();
    }
    if (availableRetailOutlets != null) {
      data['available_retail_outlets'] = availableRetailOutlets!.map((v) => v.toJson()).toList();
    }
    if (availableEwallets != null) {
      data['available_ewallets'] = availableEwallets!.map((v) => v.toJson()).toList();
    }
    if (availableQrCodes != null) {
      data['available_qr_codes'] = availableQrCodes!.map((v) => v.toJson()).toList();
    }
    if (availableDirectDebits != null) {
      data['available_direct_debits'] = availableDirectDebits!.map((v) => v.toJson()).toList();
    }
    if (availablePaylaters != null) {
      data['available_paylaters'] = availablePaylaters!.map((v) => v.toJson()).toList();
    }
    data['should_exclude_credit_card'] = shouldExcludeCreditCard;
    data['should_send_email'] = shouldSendEmail;
    data['created'] = created;
    data['updated'] = updated;
    data['currency'] = currency;
    data['metadata'] = metadata;
    return data;
  }
}

class AvailableBanks {
  String? bankCode;
  String? collectionType;
  int? transferAmount;
  String? bankBranch;
  String? accountHolderName;
  int? identityAmount;

  AvailableBanks({this.bankCode, this.collectionType, this.transferAmount, this.bankBranch, this.accountHolderName, this.identityAmount});

  AvailableBanks.fromJson(Map<String, dynamic> json) {
    bankCode = json['bank_code'];
    collectionType = json['collection_type'];
    transferAmount = json['transfer_amount'];
    bankBranch = json['bank_branch'];
    accountHolderName = json['account_holder_name'];
    identityAmount = json['identity_amount'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['bank_code'] = bankCode;
    data['collection_type'] = collectionType;
    data['transfer_amount'] = transferAmount;
    data['bank_branch'] = bankBranch;
    data['account_holder_name'] = accountHolderName;
    data['identity_amount'] = identityAmount;
    return data;
  }
}

class AvailableRetailOutlets {
  String? retailOutletName;

  AvailableRetailOutlets({this.retailOutletName});

  AvailableRetailOutlets.fromJson(Map<String, dynamic> json) {
    retailOutletName = json['retail_outlet_name'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['retail_outlet_name'] = retailOutletName;
    return data;
  }
}

class AvailableEwallets {
  String? ewalletType;

  AvailableEwallets({this.ewalletType});

  AvailableEwallets.fromJson(Map<String, dynamic> json) {
    ewalletType = json['ewallet_type'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['ewallet_type'] = ewalletType;
    return data;
  }
}

class AvailableQrCodes {
  String? qrCodeType;

  AvailableQrCodes({this.qrCodeType});

  AvailableQrCodes.fromJson(Map<String, dynamic> json) {
    qrCodeType = json['qr_code_type'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['qr_code_type'] = qrCodeType;
    return data;
  }
}

class AvailableDirectDebits {
  String? directDebitType;

  AvailableDirectDebits({this.directDebitType});

  AvailableDirectDebits.fromJson(Map<String, dynamic> json) {
    directDebitType = json['direct_debit_type'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['direct_debit_type'] = directDebitType;
    return data;
  }
}

class AvailablePaylaters {
  String? paylaterType;

  AvailablePaylaters({this.paylaterType});

  AvailablePaylaters.fromJson(Map<String, dynamic> json) {
    paylaterType = json['paylater_type'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['paylater_type'] = paylaterType;
    return data;
  }
}
