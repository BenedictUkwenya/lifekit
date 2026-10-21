import 'package:flutter_test/flutter_test.dart';
import 'package:lifekit_frontend/features/admin/admin_strings.dart';
import 'package:lifekit_frontend/features/admin/widgets/admin_ui.dart';

void main() {
  group('AdminStrings', () {
    test('translates and interpolates', () {
      expect(const AdminStrings('en')('itemsNeedAttention', {'n': '3'}),
          '3 items need your attention');
      expect(const AdminStrings('ru')('membersCount', {'n': '7'}), 'Участников: 7');
    });

    test('falls back to English, then to the key', () {
      expect(const AdminStrings('de')('approve'), 'Approve');
      expect(const AdminStrings('en')('no_such_key'), 'no_such_key');
    });

    test('status labels are translated or title-cased', () {
      expect(const AdminStrings('ka').status('pending'), 'მოლოდინში');
      expect(const AdminStrings('en').status('weird_state'), 'Weird_state');
    });
  });

  group('admin formatting', () {
    test('money handles numbers and numeric strings', () {
      expect(adminMoney(1234.5), '\$1,234.50');
      expect(adminMoney('12'), '\$12.00');
      expect(adminMoney(null), '\$0.00');
    });

    test('refs mirror the web LYF format', () {
      expect(adminRef('abcd1234-ef'), 'LYFABCD');
      expect(adminRef('ab'), '#ab');
    });

    test('status pill colours group by meaning', () {
      expect(AdminStatusPill.colorsFor('completed'), AdminStatusPill.colorsFor('active'));
      expect(AdminStatusPill.colorsFor('blocked'), AdminStatusPill.colorsFor('disputed'));
    });
  });
}
