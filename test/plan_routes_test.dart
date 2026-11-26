import 'package:flutter_test/flutter_test.dart';
import 'package:lifekit_frontend/features/home/plan_actions.dart';

void main() {
  test('old wallet tasks become payment details (LifeKit holds no money)', () {
    const t = 'Set up your wallet so you can securely receive payments from your gaming sessions.';
    expect(isLegacyWalletTask('wallet', t), isTrue);
    expect(isLegacyWalletTask('profile', t), isTrue); // wording alone is enough
    expect(resolvePlanRoute('wallet', t), 'payment_details');
  });

  test('tasks Gracy left without a screen get one from their wording', () {
    expect(resolvePlanRoute('none', 'Reach out to potential clients or partners who have posted about needing a gaming buddy.'), 'feeds');
    expect(resolvePlanRoute('none', 'Review your service performance and update your availability for the coming week.'), 'my_services');
    expect(resolvePlanRoute('none', 'Introduce yourself in the gaming community and share your interests.'), 'communities');
    expect(resolvePlanRoute('none', 'Create your first service as a gaming partner.'), 'create_service');
    expect(planActionAvailable('none', 'Reach out to potential clients'), isTrue);
  });

  test('known routes are kept; unknown wording stays without a button', () {
    expect(resolvePlanRoute('explore', 'anything'), 'explore');
    expect(resolvePlanRoute('payment_details', 'x'), 'payment_details');
    expect(resolvePlanRoute('none', 'Drink some water'), 'none');
    expect(planActionAvailable('none', 'Drink some water'), isFalse);
  });
}
