import 'package:flutter_test/flutter_test.dart';
import 'package:sky_height_pg/core/utils/validators.dart';

void main() {
  group('Validators Unit Tests', () {
    test('required validator', () {
      expect(Validators.required(null), 'This field is required');
      expect(Validators.required(''), 'This field is required');
      expect(Validators.required('   '), 'This field is required');
      expect(Validators.required('Valid text'), isNull);
    });

    test('email validator', () {
      expect(Validators.email(null), 'Email is required');
      expect(Validators.email(''), 'Email is required');
      expect(Validators.email('invalid-email'), 'Please enter a valid email address');
      expect(Validators.email('user@'), 'Please enter a valid email address');
      expect(Validators.email('user@example'), 'Please enter a valid email address');
      expect(Validators.email('user@example.com'), isNull);
      expect(Validators.email('rahul.sharma+test@skyheight.in'), isNull);
    });

    test('password validator', () {
      expect(Validators.password(null), 'Password is required');
      expect(Validators.password(''), 'Password is required');
      expect(Validators.password('12345'), 'Password must be at least 6 characters');
      expect(Validators.password('123456'), isNull);
      expect(Validators.password('securePassword!'), isNull);
    });

    test('phone validator', () {
      expect(Validators.phone(null), 'Phone number is required');
      expect(Validators.phone(''), 'Phone number is required');
      expect(Validators.phone('12345'), 'Please enter a valid 10-digit phone number');
      expect(Validators.phone('9876543210'), isNull);
      expect(Validators.phone('+91 98765 43210'), isNull); // 10 digits when stripped
    });

    test('positiveNumber validator', () {
      expect(Validators.positiveNumber(null), 'Please enter a valid amount');
      expect(Validators.positiveNumber(''), 'Please enter a valid amount');
      expect(Validators.positiveNumber('abc'), 'Please enter a valid amount');
      expect(Validators.positiveNumber('-10'), 'Please enter a valid amount');
      expect(Validators.positiveNumber('0'), 'Please enter a valid amount');
      expect(Validators.positiveNumber('100'), isNull);
      expect(Validators.positiveNumber('12.50'), isNull);
    });
  });
}
