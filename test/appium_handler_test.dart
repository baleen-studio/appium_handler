import 'package:flutter_test/flutter_test.dart';

import 'package:appium_handler/appium_handler.dart';

void main() {
  test('adds one to input values', () {
    final calculator = AppiumHandler();
    expect(calculator.addOne(2), 3);
    expect(calculator.addOne(-7), -6);
    expect(calculator.addOne(0), 1);
  });
}
