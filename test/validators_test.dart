import 'package:flutter_test/flutter_test.dart';
import 'package:foodlink/validators.dart';

void main() {
  test('email', () {
    expect(Validators.email(''), isNotNull);
    expect(Validators.email('a@b'), isNotNull);
    expect(Validators.email('name@example'), isNotNull);
    expect(Validators.email('name@example.com'), isNull);
    expect(Validators.email(' first.last+tag@mail.co.in '), isNull);
  });

  test('passwords', () {
    expect(Validators.passwordPresent(''), isNotNull);
    expect(Validators.passwordPresent('abc123'), isNull);
    expect(Validators.newPassword('abc12'), isNotNull);
    expect(Validators.newPassword('abcdefgh'), isNotNull);
    expect(Validators.newPassword('abcd 1234'), isNotNull);
    expect(Validators.newPassword('abcd1234'), isNull);
    expect(Validators.confirmPassword('x', 'y'), isNotNull);
    expect(Validators.confirmPassword('abcd1234', 'abcd1234'), isNull);
  });

  test('text lengths', () {
    expect(Validators.text('  ', field: 'Name', min: 2, max: 50), isNotNull);
    expect(Validators.text('A', field: 'Name', min: 2, max: 50), isNotNull);
    expect(Validators.text('Al', field: 'Name', min: 2, max: 50), isNull);
    expect(Validators.optionalText('', field: 'Details', max: 5), isNull);
    expect(Validators.optionalText('123456', field: 'Details', max: 5), isNotNull);
  });

  test('numbers', () {
    expect(Validators.intInRange('0', field: 'P', min: 1, max: 1000), isNotNull);
    expect(Validators.intInRange('1001', field: 'P', min: 1, max: 1000), isNotNull);
    expect(Validators.intInRange('1000', field: 'P', min: 1, max: 1000), isNull);
    expect(Validators.money('0', field: 'Price', max: 10000), isNull);
    expect(Validators.money('20.50', field: 'Price', max: 10000), isNull);
    expect(Validators.money('20.505', field: 'Price', max: 10000), isNotNull);
    expect(Validators.money('.', field: 'Price', max: 10000), isNotNull);
    expect(Validators.money('10001', field: 'Price', max: 10000), isNotNull);
  });

  test('pickup code', () {
    expect(Validators.pickupCode('12345'), isNotNull);
    expect(Validators.pickupCode('12a456'), isNotNull);
    expect(Validators.pickupCode('123456'), isNull);
  });
}
