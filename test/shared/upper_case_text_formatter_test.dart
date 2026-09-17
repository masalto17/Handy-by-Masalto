import 'package:event_radio_app/src/shared/presentation/upper_case_text_formatter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const formatter = UpperCaseTextFormatter();

  TextEditingValue format(String oldText, String newText) {
    return formatter.formatEditUpdate(
      TextEditingValue(text: oldText),
      TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      ),
    );
  }

  test('uppercases typed text', () {
    expect(format('sat', 'sati').text, 'SATI');
  });

  test('preserves cursor position', () {
    final result = format('sat', 'sati');
    expect(result.selection.baseOffset, 4);
  });

  test('leaves already uppercase input untouched', () {
    final value = TextEditingValue(
      text: 'SATI26',
      selection: const TextSelection.collapsed(offset: 6),
    );
    final result = formatter.formatEditUpdate(
      const TextEditingValue(text: 'SATI2'),
      value,
    );
    expect(result, value);
  });

  test('handles digits and empty input', () {
    expect(format('', '26').text, '26');
    expect(format('a', '').text, '');
  });
}
