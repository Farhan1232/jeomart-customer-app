/// Controls what a driver can learn about the customer while a bidding ride is
/// still open for offers.
///
/// A normal booking embeds the customer's whole profile in `rides/{id}.author`
/// - phone number included - and the dispatcher hands that document to the one
/// driver it picked. Bidding fans the same request out to many drivers at
/// once, most of whom will not get the ride, so the phone number must not be
/// in the document they read.
///
/// This is done by **not writing the field**, not by hiding a button: while
/// bidding is open the ride document simply has no `author.phoneNumber`, so
/// there is nothing for a modified driver client, a console session or an
/// exported document to read. The customer's own acceptance transaction is
/// what puts the contact details on the ride, at the moment a driver is
/// actually booked, after which the driver's contact card behaves exactly as
/// it does for a normal booking.
///
/// The list below is an **allowlist**. Anything added to `UserModel` later is
/// withheld by default rather than leaked by default.
class RideAuthorPrivacy {
  /// Author fields a driver may see while deciding whether to bid.
  ///
  /// * `id`, `firstName`, `lastName`, `profilePictureURL` - who the ride is
  ///   for, which is what the driver is judging.
  /// * `role` - the apps branch on it when rendering the ride.
  /// * `reviewsCount` / `reviewsSum` - the customer's own rating, already
  ///   public on every completed ride.
  /// * `fcmToken` - carried so a counter-offer notification can reach the
  ///   customer from the driver's device, which is how every other
  ///   notification in this project is sent. It is a rotating device handle,
  ///   not contact information, and it is the only field here that is not
  ///   already visible to the driver after a normal dispatch.
  static const Set<String> allowedBeforeAcceptance = <String>{
    'id',
    'firstName',
    'lastName',
    'profilePictureURL',
    'role',
    'reviewsCount',
    'reviewsSum',
    'fcmToken',
  };

  /// Fields that are withheld until acceptance and then written by the
  /// customer's own acceptance transaction.
  static const Set<String> revealedOnAcceptance = <String>{
    'phoneNumber',
    'countryCode',
    'countryISOCode',
    'email',
  };

  /// Ride fields — outside `author` — that must not be on a request while
  /// every eligible driver can read it.
  ///
  /// `otpCode` is the code the customer reads out at pickup to prove the
  /// arriving driver is the one they booked. In a normal booking exactly one
  /// driver is ever handed it. A bidding request goes to up to
  /// `maxDriversPerRequest` drivers at once, so leaving it on the open request
  /// would hand the pickup code to nineteen people who did not get the ride.
  /// It is written by the acceptance transaction instead, to the winner only.
  static const Set<String> withheldRideFields = <String>{'otpCode'};

  /// Shapes a whole ride document for the open bidding phase: the author is
  /// reduced to the allowlist, and the withheld ride fields are removed.
  ///
  /// One function so the policy lives in one place and the tests can assert on
  /// it directly, rather than being spread across the write path.
  static Map<String, dynamic> redactRide(Map<String, dynamic> ride, {Map<String, dynamic>? author}) {
    final Map<String, dynamic> shaped = Map<String, dynamic>.from(ride);
    shaped['author'] = redact(author ?? (ride['author'] is Map ? Map<String, dynamic>.from(ride['author'] as Map) : null));
    for (final String field in withheldRideFields) {
      shaped.remove(field);
    }
    return shaped;
  }

  /// True when a ride document still carries something an open request must
  /// not expose — a contact detail, or a withheld field such as the OTP.
  static bool leaksOnOpenRequest(Map<String, dynamic>? ride) {
    if (ride == null) return false;
    for (final String field in withheldRideFields) {
      final Object? value = ride[field];
      if (value != null && value.toString().isNotEmpty) return true;
    }
    final Object? author = ride['author'];
    return leaksContact(author is Map ? Map<String, dynamic>.from(author) : null);
  }

  /// The author map to store on a ride that is open for bids.
  static Map<String, dynamic> redact(Map<String, dynamic>? author) {
    final Map<String, dynamic> redacted = <String, dynamic>{};
    if (author == null) return redacted;
    for (final String key in allowedBeforeAcceptance) {
      if (author.containsKey(key)) redacted[key] = author[key];
    }
    return redacted;
  }

  /// The patch the acceptance transaction applies to `rides/{id}`, which
  /// restores the author to what a normal booking has always stored.
  ///
  /// Written as one nested `author` map rather than dotted paths so it merges
  /// cleanly through `set(..., merge: true)` as well as `update()`.
  static Map<String, dynamic> contactPatch(Map<String, dynamic>? author) {
    if (author == null) return <String, dynamic>{};
    return <String, dynamic>{'author': author};
  }

  /// The author map stored on a normal (non-bidding) ride when it is booked.
  ///
  /// A normal ride used to carry the customer's whole profile - phone, email,
  /// wallet balance, bank details, every saved address, live location - and
  /// the dispatcher copies the ride onto each driver it offers it to. Now it
  /// carries the same allowlist a bidding request does. The contact details
  /// phone number is added by [contactFields] once a driver has actually
  /// accepted; the email is never added.
  ///
  /// `shippingAddress` is written as an empty list, not left out: the admin
  /// panel's SOS page reads `author.shippingAddress.<field>` without a guard.
  static Map<String, dynamic> forSystemRide(Map<String, dynamic>? author) {
    final Map<String, dynamic> shaped = redact(author);
    shaped['shippingAddress'] = <dynamic>[];
    return shaped;
  }

  /// Fields a normal ride gains once a driver has accepted it: the phone
  /// number only. The email is never put on a normal ride.
  static const Set<String> systemRidePhoneFields = <String>{
    'phoneNumber',
    'countryCode',
    'countryISOCode',
  };

  /// The customer's phone number, and nothing else, for a ride a driver has
  /// accepted. Empty values are left out so nothing is blanked.
  static Map<String, dynamic> contactFields(Map<String, dynamic>? author) {
    final Map<String, dynamic> contact = <String, dynamic>{};
    if (author == null) return contact;
    for (final String key in systemRidePhoneFields) {
      final Object? value = author[key];
      if (value != null && value.toString().isNotEmpty) contact[key] = value;
    }
    return contact;
  }

  /// True when [rideAuthor] does not yet hold every value in [contact].
  static bool contactMissing(Map<String, dynamic>? rideAuthor, Map<String, dynamic> contact) {
    for (final MapEntry<String, dynamic> entry in contact.entries) {
      if (rideAuthor == null || rideAuthor[entry.key]?.toString() != entry.value.toString()) return true;
    }
    return false;
  }

  /// True when the map still carries something that must not be there before
  /// acceptance. Used by the tests, and cheap enough to assert on in debug.
  static bool leaksContact(Map<String, dynamic>? author) {
    if (author == null) return false;
    for (final String key in revealedOnAcceptance) {
      final Object? value = author[key];
      if (value != null && value.toString().isNotEmpty) return true;
    }
    return false;
  }
}
