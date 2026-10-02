import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cat_eyekeeper/theme/app_colors.dart';

void main() {
  test('colorFromHex parses a 6-digit hex as fully opaque', () {
    final color = colorFromHex('#4C6FFF');
    expect(color.r, closeTo(0x4C / 255, 0.01));
    expect(color.g, closeTo(0x6F / 255, 0.01));
    expect(color.b, closeTo(0xFF / 255, 0.01));
    expect(color.a, closeTo(1.0, 0.01));
  });

  test('colorFromHex falls back to opaque black on malformed input', () {
    expect(colorFromHex('not a color'), const Color(0xFF000000));
  });

  test('colorToHex round-trips colorFromHex', () {
    const original = '#4C6FFF';
    final roundTripped = colorToHex(colorFromHex(original));
    expect(roundTripped, original);
  });

  test('colorToHex does not encode alpha', () {
    final translucent = colorFromHex('#4C6FFF').withValues(alpha: 0.3);
    expect(colorToHex(translucent), '#4C6FFF');
  });
}
