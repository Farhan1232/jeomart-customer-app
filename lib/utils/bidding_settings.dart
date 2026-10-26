/// Global bidding configuration, read from `settings/biddingSettings`.
///
/// Two switches, deliberately independent, as the brief requires:
///
/// * [enabled] turns the whole bidding / counter-offer feature on. While it is
///   off the taxi booking flow behaves exactly as it always has - no bidding
///   screen, no offer list, no extra document is written.
/// * [minimumFarePerKmEnabled] turns the minimum-fare-per-km floor on. It only
///   means anything while bidding is on, but it is stored and read separately
///   so the admin can switch either without touching the other.
///
/// Nothing here is hardcoded in the apps: an absent or unreadable settings
/// document reads as **everything off**, which is the pre-bidding behaviour.
class BiddingSettings {
  const BiddingSettings({
    this.enabled = false,
    this.minimumFarePerKmEnabled = false,
    this.minimumFarePerKm = 0,
    this.bidExpiryMinutes = defaultBidExpiryMinutes,
    this.maxDriversPerRequest = defaultMaxDriversPerRequest,
    this.testUids = const <String>[],
  });

  /// The settings document id inside the existing `settings` collection.
  static const String documentId = 'biddingSettings';

  /// Used when the admin has never saved a value. Matches the default the
  /// admin panel writes on its first save.
  static const int defaultBidExpiryMinutes = 5;
  static const int defaultMaxDriversPerRequest = 20;

  /// The global BIDDING ON/OFF switch.
  final bool enabled;

  /// The separate MINIMUM FARE PER KM ON/OFF switch.
  final bool minimumFarePerKmEnabled;

  /// One global rate. Deliberately not per vehicle type - the brief is
  /// explicit that vehicle-specific minimums must not be created.
  final num minimumFarePerKm;

  /// How long a dispatched bidding request stays open for offers.
  final int bidExpiryMinutes;

  /// How many eligible drivers one request fans out to.
  final int maxDriversPerRequest;

  /// ── TEMPORARY DEVELOPMENT TEST SCOPE ──────────────────────────────────
  /// A list of user ids allowed into the bidding flow while [enabled] is
  /// still false, so the feature can be exercised end-to-end against the
  /// production project without exposing it to real customers and drivers.
  ///
  /// **Empty in production, and empty is the whole point:** with no uids in
  /// the list [isEnabledFor] reduces to [enabled] exactly, so the shipped
  /// behaviour is the plain global switch the client asked for. Delete the
  /// `testUids` field from `settings/biddingSettings` to remove the test
  /// scope; no code change and no app update is needed.
  final List<String> testUids;

  /// The all-off configuration. Used when the document is missing, empty or
  /// unreadable, so a settings outage can never silently switch bidding on.
  static const BiddingSettings disabled = BiddingSettings();

  /// Reads the settings document. Every field is defensive: the admin panel
  /// writes numbers, but older hand-edited documents in this project store
  /// numbers as strings, so both are accepted.
  factory BiddingSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return disabled;
    return BiddingSettings(
      enabled: _readBool(json['enabled']),
      minimumFarePerKmEnabled: _readBool(json['minimumFarePerKmEnabled']),
      minimumFarePerKm: _readNum(json['minimumFarePerKm']) ?? 0,
      bidExpiryMinutes: (_readNum(json['bidExpiryMinutes']) ?? defaultBidExpiryMinutes).round().clamp(1, 120),
      maxDriversPerRequest: (_readNum(json['maxDriversPerRequest']) ?? defaultMaxDriversPerRequest).round().clamp(1, 100),
      testUids: _readStringList(json['testUids']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'enabled': enabled,
        'minimumFarePerKmEnabled': minimumFarePerKmEnabled,
        'minimumFarePerKm': minimumFarePerKm,
        'bidExpiryMinutes': bidExpiryMinutes,
        'maxDriversPerRequest': maxDriversPerRequest,
        if (testUids.isNotEmpty) 'testUids': testUids,
      };

  /// Whether the minimum-fare floor actually applies. Both the switch and a
  /// usable rate are required: a switch left on with the rate cleared to 0
  /// must not silently reject every offer.
  bool get hasMinimumFare => enabled && minimumFarePerKmEnabled && minimumFarePerKm > 0;

  /// Whether [uid] may use the bidding flow.
  ///
  /// * [enabled] true  -> everybody, which is the production behaviour.
  /// * [enabled] false and [testUids] empty -> nobody, which is also the
  ///   production behaviour: identical to reading [enabled] on its own.
  /// * [enabled] false and [testUids] populated -> only those uids. This is
  ///   the TEMPORARY test scope described on [testUids].
  bool isEnabledFor(String? uid) {
    if (enabled) return true;
    if (testUids.isEmpty) return false;
    return uid != null && uid.isNotEmpty && testUids.contains(uid);
  }

  static bool _readBool(Object? raw) {
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    if (raw is String) return raw.toLowerCase() == 'true' || raw == '1';
    return false;
  }

  static num? _readNum(Object? raw) {
    if (raw is num) return raw;
    if (raw is String) return num.tryParse(raw.trim());
    return null;
  }

  static List<String> _readStringList(Object? raw) {
    if (raw is! List) return const <String>[];
    return raw
        .whereType<Object>()
        .map((Object e) => e.toString().trim())
        .where((String e) => e.isNotEmpty)
        .toList(growable: false);
  }
}
