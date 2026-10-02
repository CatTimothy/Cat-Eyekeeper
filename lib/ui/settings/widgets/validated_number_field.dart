import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A digit-only text field for the three validated numeric settings
/// (reminder interval, break duration, idle threshold). Input is
/// restricted to digits as the user types; range validation itself
/// happens centrally in SettingsScreen at Save time, since it needs to
/// check all three fields together and surface one combined error.
class ValidatedNumberField extends StatelessWidget {
  const ValidatedNumberField({
    super.key,
    required this.label,
    required this.controller,
    required this.maxDigits,
    required this.suffixText,
  });

  final String label;
  final TextEditingController controller;
  final int maxDigits;
  final String suffixText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), suffixText: suffixText),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(maxDigits)],
    );
  }
}
