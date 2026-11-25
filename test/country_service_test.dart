import 'package:flutter_test/flutter_test.dart';
import 'package:lifekit_frontend/core/services/country_service.dart';

void main() {
  test('country codes become flags, bad codes fall back to Georgia', () {
    expect(CountryService.flagEmoji('NG'), '🇳🇬');
    expect(CountryService.flagEmoji('ge'), '🇬🇪');
    expect(CountryService.flagEmoji('US'), '🇺🇸');
    expect(CountryService.flagEmoji(''), '🇬🇪');
    expect(CountryService.flagEmoji('N1'), '🇬🇪');
  });
}
