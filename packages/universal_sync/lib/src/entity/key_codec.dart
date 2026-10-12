import 'dart:convert';
import 'dart:typed_data';

/// Canonical wire key encoding: a JSON array of primary-key values.
String encodeKeyJson(List<Object?> parts) => jsonEncode(parts);

/// Stable 8-byte digest of [keyJson], used for indexed lookups.
///
/// Two independent 32-bit FNV-style accumulators with 16-bit-safe
/// multiplication, so the result is identical on the VM and on the web
/// (where integer multiplication must stay below 2^53).
Uint8List keyHashOf(String keyJson) {
  var h1 = 0x811c9dc5;
  var h2 = 0x9e3779b9;
  for (final byte in utf8.encode(keyJson)) {
    h1 = _mul32((h1 ^ byte) & _mask32, 0x01000193);
    h2 = _mul32((h2 + byte) & _mask32, 0x85ebca6b);
    h2 = (h2 ^ (h2 >> 13)) & _mask32;
  }
  final out = Uint8List(8);
  final view = ByteData.view(out.buffer);
  view.setUint32(0, h1, Endian.big);
  view.setUint32(4, h2, Endian.big);
  return out;
}

const int _mask32 = 0xFFFFFFFF;

int _mul32(int a, int b) {
  final aLo = a & 0xFFFF;
  final aHi = (a >> 16) & 0xFFFF;
  return ((aLo * b) + ((aHi * b) & 0xFFFF) * 0x10000) & _mask32;
}
