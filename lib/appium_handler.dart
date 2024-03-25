library appium_handler;

import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_driver/flutter_driver.dart';
import 'package:package_info_plus/package_info_plus.dart';


/// A Calculator.
class AppiumHandler {
  /// Returns [value] plus 1.
  int addOne(int value) => value + 1;

  PackageInfo? _packageInfo;
  int _index = 0;
  String _source = "";
  final jsonEncoder = const JsonEncoder();

  void _inspectElement(Element element) {
    // Inspect the current element
    FlutterDriver.connect().then((driver) => {
      driver.sendCommand(const GetRenderTree(timeout: Duration(seconds: 360))).then((value) => {
        debugPrint(jsonEncoder.convert(value)),
        inspect(value)
      })
    });

    var type = element.widget.runtimeType.toString();
    var left = element.renderObject?.semanticBounds.left;
    var top = element.renderObject?.semanticBounds.top;
    var right = element.renderObject?.semanticBounds.right;
    var bottom = element.renderObject?.semanticBounds.bottom;

    Offset? topLeft;
    Offset? bottomRight;
    if (element.renderObject is RenderBox) {
      final renderBox = element.renderObject! as RenderBox;
      topLeft = renderBox.localToGlobal(Offset(left!, top!));
      bottomRight = renderBox.localToGlobal(Offset(right!, bottom!));
    } else {
      topLeft = Offset(left!, top!);
      bottomRight = Offset(right!, bottom!);
    }
    String? text = '';
    var finder = find.descendant(
      of: find.byType(element.widget.runtimeType.toString()),
      matching: find.byType("Text"),
    );
    var result = finder.serialize();
    if (result.isNotEmpty) {
      result.forEach((String key, String value) {
        if (value == "true") {
          text = key;
        }
      });
    }

    finder = find.descendant(
      of: find.byType(element.widget.runtimeType.toString()),
      matching: find.byType("Checkbox"),
    );
    finder = find.descendant(
      of: find.byType(element.widget.runtimeType.toString()),
      matching: find.byType("Radio"),
    );

    _source = '$_source<$type index="$_index" package="${_packageInfo!.packageName}" class="$type" text="$text" checkable="false" checked="false" clickable="false" enabled="true" focusable="false" focused="false" long-clickable="false" password="false" scrollable="false" selected="false" bounds="[${topLeft.dx.toInt()},${topLeft.dy.toInt()}][${bottomRight.dx.toInt()},${bottomRight.dy.toInt()}]" displayed="true">\r\n';
    // Recursively inspect child elements
    element.visitChildren((child) {
      _inspectElement(child);
    });
    _source += '</$type>\r\n';
    ++_index;
  }

  Future<String> appiumHandler(String? cmd) async {
    _packageInfo = await PackageInfo.fromPlatform();
    //var message = cmd!.replaceAll('{', '').replaceAll('}', '');
    //var parts = message.split(':');
    var msg = cmd;  //parts[1].trim();
    if (msg == 'getScreenSize') {
      // some call handling in the application
      final screenSize = WidgetsBinding.instance!.window.physicalSize;
      return jsonEncode({'width': screenSize.width, 'height': screenSize.height});
    } else if (msg == 'getPageSource') {
      Element? rootElement = WidgetsBinding.instance.rootElement;  // .renderViewElement;
      if (rootElement != null) {
        // Traverse the widget tree
        _index = 0;
        _source = "";
        _inspectElement(rootElement);
        return _source;
      }
    } else {
      try {
        // Attempt to decode the JSON string
        var jsonObject = jsonDecode(cmd!);
        if (jsonObject is List) {
          return _performActions(jsonObject);
        }
      } catch (e) {
        // Handle any exceptions thrown during decoding
        debugPrint('Error decoding JSON: $e');
      }
    }
    return jsonEncode({'width': msg, 'height': msg});
  }

  Future<String> _performActions(List<dynamic> jsonObject) async {
    List<dynamic> performs = jsonObject[0];
    for (Map<String, dynamic> element in performs) {
      var type = element['type'];
      var id = element['id'];
      Map<String, dynamic> parameters = element['parameters'];
      var pointerType = parameters['pointerType'];
      List<Map<String, dynamic>> actions = element['actions'];
      int? moveDuration;
      int? pauseDuration;
      int? x;
      int? y;
      int? downButton;
      int? upButton;
      for (Map<String, dynamic> action in actions) {
        var type = action['type'];
        switch (type) {
          case "pointerMove":
            moveDuration = action['duration'];
            x = action['x'];
            y = action['y'];
            break;
          case "pointerDown":
            downButton = action['button'];
            break;
          case "pause":
            pauseDuration = action['duration'];
            break;
          case "pointerUp":
            upButton = action['button'];
            break;
        }
      }
    }
    String uuid = jsonObject[1] as String;
    return "";
  }
}
