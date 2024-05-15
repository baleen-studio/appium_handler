import 'package:flutter_test/flutter_test.dart';

import 'package:appium_handler/appium_handler.dart';
import 'package:appium_handler/widget_tree.dart';

void main() {
  final i = MyInspectorController();
  i.computeTreeRoot();

  test('adds one to input values', () {
    final calculator = AppiumHandler();
    expect(calculator.addOne(2), 3);
    expect(calculator.addOne(-7), -6);
    expect(calculator.addOne(0), 1);
  });
}
