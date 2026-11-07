/// Demo-only seed values for the hackathon build. Not real credentials.
///
/// Partner cockpit login (for judges/partners): ID `PTR-1001`, PIN `482916`.
/// Only the salted hash of the PIN is compiled in.
class DemoSeed {
  static const partnerId = 'PTR-1001';
  static const partnerPinSalt = 'ekko-partner-v1';

  /// sha256('ekko-partner-v1:PTR-1001:482916')
  static const partnerPinHash = 'b844c3acd80d0a1d41427f55f845d467e84bc34727ec5922524a202f01bf7dfb';
}
