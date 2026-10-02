import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polar_glow/core/widgets/phone_formatter.dart';

void main() {
  final formatter = PhoneFormatter();

  TextEditingValue apply(String text) {
    return formatter.formatEditUpdate(
      TextEditingValue.empty,
      TextEditingValue(text: text),
    );
  }

  test('formats a full 10-digit Alaska number', () {
    expect(apply('9074065088').text, '(907) 406-5088');
  });

  test('formats partial input', () {
    expect(apply('907').text, '907');
    expect(apply('9074').text, '(907) 4');
    expect(apply('907406').text, '(907) 406');
  });

  test('rejects more than 10 digits', () {
    final old = apply('9074065088');
    final next = formatter.formatEditUpdate(
      old,
      TextEditingValue(
        text: '90740650881',
        selection: const TextSelection.collapsed(offset: 11),
      ),
    );
    expect(next.text, old.text);
  });
}
