/// Client-requested visibility switches for **customer registration fields**.
///
/// Session 4 requirement: *"Hide Referral Code from registration page — Customer
/// App"*.
///
/// This is a **form** requirement, not a data one. Nothing referral-related is
/// removed:
///
/// * `models/referral_model.dart` and the `referral` collection are untouched,
///   and every existing `referral/{uid}` document keeps its `referralCode` and
///   `referralBy`.
/// * `screen_ui/multi_vendor_service/refer_friend_screen/` still shows the
///   customer their own code and still lets them share it - so a customer can
///   still refer other people, they just cannot be *asked* for a code while
///   signing up.
/// * Registration still creates the new customer's own `referral` document, so
///   Refer a Friend works for accounts created after this change exactly as it
///   does for accounts created before it.
///
/// The only behavioural difference is that no code is collected at signup, so
/// `referralBy` is empty for new accounts - which is already what happened
/// whenever a customer left the field blank.
class RegistrationFieldVisibility {
  const RegistrationFieldVisibility._();

  /// The "Referral Code" text field on the sign-up screen.
  ///
  /// Hidden per the client's Session 4 requirement. `SignUpController` keeps
  /// `referralCodeEditingController` so the field can be restored by flipping
  /// this flag alone, and reads it defensively: with the field hidden the text
  /// is always empty, and the sign-up path skips the referral lookup rather
  /// than querying Firestore for an empty code.
  static const bool showReferralCode = false;

  /// The referral code to actually use, given whatever is in the text field.
  ///
  /// One place decides this so the two callers - the "is this code valid?"
  /// check and the `referral` document write - can never disagree about
  /// whether a code was supplied. With [showReferralCode] false the answer is
  /// always `""`, which is the same answer registration already produced for a
  /// customer who left the field blank.
  static String referralCodeFrom(String? rawInput) {
    if (!showReferralCode) return "";
    return (rawInput ?? "").trim();
  }
}
