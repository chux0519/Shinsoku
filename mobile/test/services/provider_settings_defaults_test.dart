import 'package:flutter_test/flutter_test.dart';
import 'package:shinsoku_mobile/services/provider_settings.dart';

void main() {
  test('defaults carry no API keys and the provider is not configured', () {
    final defaults = ProviderSettings.defaults();
    expect(defaults.bailianApiKey, isEmpty);
    expect(defaults.sonioxApiKey, isEmpty);
    expect(defaults.activeProviderConfigured, isFalse);
  });
}
