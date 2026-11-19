import 'package:shinsoku_mobile/services/region_defaults_store.dart';

/// A map-backed storage; [failAfter] makes the n-th write throw (crash
/// mid-apply).
class MapStorage implements SettingsStorage {
  MapStorage([Map<String, String>? initial, this.failAfter])
    : values = {...?initial};

  final Map<String, String> values;
  int? failAfter;
  var writes = 0;
  var readFails = false;

  @override
  Future<Map<String, String>> readAll() async {
    if (readFails) throw StateError('locked');
    return Map.of(values);
  }

  @override
  Future<void> write(String key, String value) async {
    if (failAfter != null && writes >= failAfter!) {
      throw StateError('storage full');
    }
    writes++;
    values[key] = value;
  }
}
