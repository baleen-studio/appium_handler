library appium_handler;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:developer';
import 'dart:isolate';
import 'dart:ui';

import 'package:appium_handler/widget_tree.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
//import 'package:visibility_detector/visibility_detector.dart';
import 'package:test/test.dart';
import 'package:flutter_driver/flutter_driver.dart';

import 'package:appium_handler/driver_extension.dart';

/// A Calculator.
class AppiumHandler/* with WidgetInspectorService*/ {
  static final AppiumHandler _instance = AppiumHandler._internal();

  factory AppiumHandler() {
    return _instance;
  }

  AppiumHandler._internal();
  
  /// Returns [value] plus 1.
  //int addOne(int value) => value + 1;

  int _index = 0;
  String _source = "";
  final jsonEncoder = const JsonEncoder();
  XmlDocument? _document;
  MyDriverExtension? _driverExtension;
  var uuid = const Uuid();
  final _receivePort = ReceivePort();
  final Map<String, List<Offset>> _treeItemOffsets = {};

  MyDriverExtension? get driverExtension => _driverExtension;

  //set myApp(StatelessWidget app) {
  //  _myApp = app;
  //}
  //BuildContext? get buildContext => _context;
  //set buildContext(BuildContext? context) {
  //  _context = context;
  //}
  SendPort get mySendPort => _receivePort.sendPort;
  set senderPort(SendPort sendPort) {
    //_senderPort?.send(_receivePort.sendPort);
  }

  buildDriverExtension() {
    _driverExtension = MyDriverExtension(appiumHandler, true, false);
  }

  Future<void> testTap(String text) async {
    Map<String, String> params = {
      "command":"tap","finderType":"ByType","type":text
    };
    var responseFuture = _driverExtension?.call(params);
  /*
    Map<String, String> params = {
      "command":"get_layer_tree","finderType":"ByText","text":text
    };
    var responseFuture = _driverExtension?.call(params);
    var response = await responseFuture;
    debugPrint(response.toString());
   */
  }

  Future<String> appiumHandler(String? cmd) async {
  //sendMail(subject: "apiHandler", body:cmd);
    var cmdAndArg = cmd?.split(':');
    var msg = cmdAndArg?[0]; //parts[1].trim();
    switch(msg) {
      case 'getScreenSize':
        FlutterView view = PlatformDispatcher.instance.views.first;

        double physicalWidth = view.physicalSize.width;
        double physicalHeight = view.physicalSize.height;

        double devicePixelRatio = view.devicePixelRatio;

        double screenWidth = physicalWidth / devicePixelRatio;
        double screenHeight = physicalHeight / devicePixelRatio;
        return jsonEncode({'width': screenWidth.toInt(), 'height': screenHeight.toInt()});
      case 'getPageSource':
        final tree = MyWidgetInspectorService();

        void layoutTree(Map<String, dynamic>? element) {
          final valueId = element?['valueId'];

          double left = 0.0;
          double top = 0.0;
          double width = 0.0;
          double height = 0.0;

          final layout = tree.getLayoutExplorerNode({'id':valueId, 'subtreeDepth': '100000', "groupName": "tree_1"});
          Map<String, dynamic> result = layout['result'] as Map<String, dynamic>;
          Map<String, dynamic> size = result['size'];
          width = double.parse(size['width']);
          height = double.parse(size['height']);
          if (result['parentData'] != null) {
            Map<String, dynamic> parentData = result['parentData'];
            left = double.parse(parentData['globalX']);
            top = double.parse(parentData['globalY']);
          } else if (result['renderObject'] != null) {
            Map<String, dynamic> renderObject = result['renderObject'];
            List<dynamic> properties = renderObject['properties'];
            for (Map<String, dynamic> property in properties) {
              if (property['name'] == 'parentData') {
                String description = property['description'];
                if (description.indexOf('Offset') > 0) {
                  final parts = description.split(';');
                  int start = parts[0].indexOf('(');
                  final values = parts[0].substring(start+1);
                  int comma = values.indexOf(',');
                  final xValue = values.substring(0, comma);
                  int bracket = values.indexOf(')');
                  final yValue = values.substring(comma+2, bracket);
                  left = double.parse(xValue);
                  top = double.parse(yValue);
                }
              }
            }
          }
          Offset topLeft = Offset(left, top);
          Offset bottomRight = Offset(left+width, top+height);

          List<Offset> listOffset = [topLeft, bottomRight];
          _treeItemOffsets[valueId] = listOffset;

          if (element?['hasChildren'] as bool) {
            for (final child in element?['children']) {
              layoutTree(child);
            }
          }
        }

        void visitorTree(Map<String, dynamic>? element) {
          String runtimeType = element?['widgetRuntimeType'];
          final type = runtimeType
              .replaceAll('<', '-')
              .replaceAll('>', '-');
          final valueId = element?['valueId'];

          List<dynamic> properties = tree.myGetProperties(valueId, 'tree_1');
          String? key;
          String? text;
          String? enabled;
          String? toolTip;
          String? semanticLabel;
          for (final property in properties) {
            if (property['name'] == 'key') {
              key = property['description'] ?? '';
              key = key?.replaceAll('"', '');
              if (key == 'null') {
                key = '';
              }
            } else if (property['name'] == 'data') {
              text = property['description'] ?? '';
              text = text?.replaceAll('"', '');
              if (text == 'null') {
                text = '';
              }
            } else if (property['name'] == 'enabled') {
              enabled = property['description'] ?? '';
              enabled = enabled?.replaceAll('"', '');
              if (enabled == 'null') {
                enabled = '';
              }
            } else if (property['name'] == 'tooltip') {
              toolTip = property['description'] ?? '';
              toolTip = toolTip?.replaceAll('"', '');
              if (toolTip == 'null') {
                toolTip = '';
              }
            } else if (property['name'] == 'semanticLabel') {
              semanticLabel = property['description'] ?? '';
              semanticLabel = semanticLabel?.replaceAll('"', '');
              if (semanticLabel == 'null') {
                semanticLabel = '';
              }
            } else if (property['name'] == 'controller') {
              final txt = property['description'];
              final start = txt.indexOf('┤');
              final end = txt.indexOf('├');
              if (start > 0 && end > 0) {
                text = txt.substring(start+1, end);
              }
            }
          }

          String? pass = "false";
          bool isEditable = (runtimeType == 'TextField' || runtimeType == 'TextFormField');

          Offset topLeft = const Offset(0.0, 0.0);
          Offset bottomRight = const Offset(0.0, 0.0);
          if (_treeItemOffsets[valueId] != null) {
            final listOffset = _treeItemOffsets[valueId];
            if (listOffset != null) {
              topLeft = listOffset[0];
              bottomRight = listOffset[1];
            }
          }

          ++_index;
          _source =
          '$_source<$type id="$valueId" key="$key" index="$_index" class="$type" text="${text ?? ''}" tooltip="${toolTip ?? ''}" password="${pass ?? ''}" bounds="[${topLeft
              .dx.toInt()},${topLeft.dy.toInt()}][${bottomRight.dx
              .toInt()},${bottomRight.dy.toInt()}]" enabled="${enabled ?? ''}" semanticLabel="${semanticLabel ?? ''}" input="${isEditable ? "true" : "false"}" centerX="${((topLeft.dx+bottomRight.dx)/2).toInt()}" centerY="${((topLeft.dy+bottomRight.dy)/2).toInt()}"';
          _source += '>\n';
          if (element?['hasChildren'] as bool) {
            for (final child in element?['children']) {
              visitorTree(child);
            }
          }
          _source += '</$type>\n';
        }

        _source = '<?xml version="1.0"?>\n';
        _source += "<tree>\n";

        final result = tree.getRootWidgetSummaryTreeWithPreviews({"groupName": "tree_1"});
        layoutTree(result['result'] as Map<String, dynamic>?);
        visitorTree(result['result'] as Map<String, dynamic>?);

        _source += "</tree>\n";
        try {
          _document = XmlDocument.parse(_source);
          return _document.toString();
        } catch (e) {
          // Handle any exceptions thrown during decoding
          sendMail(subject: "XML parse", body: "Error parsing JSON: $_source");
          return _source;
        }
    case 'performActions':
      var idx = cmd?.indexOf(':');
      var json = cmd?.substring(idx! + 1).trim();
      List<dynamic>? jsonObject;
      try {
        // Attempt to decode the JSON string
        jsonObject = jsonDecode(json!);
      } catch (e) {
        // Handle any exceptions thrown during decoding
        sendMail(subject: "JSON decode", body: "Error decoding JSON: $e");
        return 'Error decoding JSON: $e';
      }
      if (jsonObject is List) {
        return await _performActions(jsonObject);
      }
      return "";
    case 'getFinderType':
      var idx = cmd?.indexOf(':');
      var json = cmd?.substring(idx! + 1).trim();
      List<Future<XmlNode>> futures = [];
      Map<String, dynamic>? jsonObject;
      try {
        // Attempt to decode the JSON string
        jsonObject = jsonDecode(json!);
      } catch (e) {
        // Handle any exceptions thrown during decoding
        sendMail(subject: "JSON decode", body: "Error decoding JSON: $e");
        return 'Error decoding JSON: $e';
      }
      String? foundBy;
      String? value;
      _document?.descendants.toList().reversed.forEach((node) async {
        final id = node.getAttribute("id");
        if (id == jsonObject?['id']) {
          foundBy = 'byType';
          value = node.getAttribute('class');

          final tooltip = node.getAttribute("tooltip");
          if (tooltip != null && tooltip.isNotEmpty) {
            foundBy = 'byToolTip';
            value = tooltip;
          }
          final semanticLabel = node.getAttribute("semanticLabel");
          if (semanticLabel != null && semanticLabel.isNotEmpty) {
            foundBy = 'bySemanticsLabel';
            value = semanticLabel;
          }
          var key = node.getAttribute("key");
          if (key != null && key.isNotEmpty) {
            foundBy = 'byValueKey';
            value = key;
          }
          final text = node.getAttribute("text");
          if (text != null && text.isNotEmpty) {
            foundBy = 'byText';
            value = text;
          }
        }
        futures.add(futureNode(node));
      });
      Future.wait(futures).then((onValue) {});
      String ret = '{"isError": false, "foundBy": "$foundBy", "text": "$value"}';
      return ret;
    case 'findElement':
      var separated = cmdAndArg?[1].split(',');
      if (_document != null && separated?[0] == 'id') {
        // id,b1a4b918-116e-464a-80cf-12c9a6029aaf,bb9c570b-b1f1-4ef1-8448-bb5003db6b73
        var ret = "{}";
        var id = separated?[1];
        _document?.descendants.forEach((node) {
          if (node.getAttribute('id') == id) {
            ret =
            '{"value":{"ELEMENT":"$id","element-6066-11e4-a52e-4f735466cecf":"$id"},"sessionId":"${separated?[2]}"}';
          }
        });
        return ret;
      } else {
        // xpath,//RawGestureDetector[@id="18525c8e-2d9a-45c1-b9fa-684b4ad777bf"],56b8d972-7b19-4dcd-8c88-8bec231ac638
        var separated = cmdAndArg?[1].split(',');
        if (_document != null && separated?[0] == 'xpath') {
          int? idIdx = separated?[1].indexOf("[@id=");
          if (idIdx != null && idIdx >= 0) {
            var id = separated?[1].substring(idIdx + "[@id=".length + 1);
            var ele = separated?[1].substring(2, idIdx);
            idIdx = id?.indexOf('"]');
            if (idIdx != null && idIdx >= 0) {
              id = id?.substring(0, idIdx).replaceAll('<', '-').replaceAll(
                  '>', '-');
            }
            if (id != null && ele != null) {
              var lines = _document?.findAllElements(ele!);
              if (lines != null) {
                for (var line in lines) {
                  if (line.getAttribute("id") == id) {
                    var element = _findSizeRoot(line);
                    if (element != null) {
                      id = element.getAttribute("id");
                    }
                    return '{"value":{"ELEMENT":"$id","element-6066-11e4-a52e-4f735466cecf":"$id"},"sessionId":"${separated?[2]}"}';
                  }
                }
                return "{}";
              }
            }
          }
        }
      }
    /*
    case 'screenShot':
      String? b64;
      FlutterDriver? driver;
      setUpAll(() async {
        final info = await Service.getInfo();
        driver = await FlutterDriver.connect(
            dartVmServiceUrl: info.serverUri.toString(),
            timeout: const Duration(seconds: 10));
        //final screen = await _driver?.screenshot();
        //b64 = base64Encode(screen!);
      });
      tearDownAll(() async {
        if (driver != null) {
          await driver!.close();
        }
      });
      //group('App test', () {
        test("Screen shot", () async {
          await driver?.waitUntilNoTransientCallbacks();
          final screen = await driver?.screenshot();
          b64 = base64Encode(screen!);
        });
      //});
      while (b64 == null) {
        sleep(const Duration(milliseconds: 1000));
      }
      return b64!;
    case 'click':
      var parts = cmdAndArg?[1].split(',');
      String? ret;
      _document?.descendants.toList().reversed.forEach((node) async {
        var id = node.getAttribute("id");
        if (id == parts?[0]) {
          final res = await _execCommandWithFinder(int.parse(node.getAttribute('centerX')!), int.parse(node.getAttribute('centerY')!), node, "tap");
          ret = jsonEncode(res);
          return;
        }
      });
      return ret ?? "{}";
    case 'setValue':
      var parts = cmdAndArg?[1].split(',');
      String? ret;
      List<Future<XmlNode>> futures = [];
      _document?.descendants.toList().reversed.forEach((node) async {
        var id = node.getAttribute("id");
        if (id == parts?[1]) {
          final x = int.parse(node.getAttribute('centerX')!);
          final y = int.parse(node.getAttribute('centerY')!);
          final res = await _execCommandWithFinder(x, y, node, "tap");
          if (!res?['isError']) {
            final res2 = await _execCommandWithFinder(
                x, y, node, "enter_text", enterText: parts?[0]);
            ret = jsonEncode(res2);
          }
        }
        futures.add(futureNode(node));
      });
      Future.wait(futures).then((onValue) {});

      return ret ?? "{}";
     */
    }
    return jsonEncode({'width': msg, 'height': msg});
  }

  Future<XmlNode> futureNode(XmlNode node) async {
    return node;
  }

  Future<String> _performActions(List<dynamic> jsonObject) async {
    Map<String, dynamic>? performs;
    if (jsonObject[0] is List<dynamic>) {
      performs = jsonObject[0][0];
    } else {
      performs = jsonObject[0];
    }
    var type = performs?['type'];
    var id = performs?['id'];
    Map<String, dynamic> parameters = performs?['parameters'];
    String? pointerType = parameters['pointerType'];
    List<dynamic> actions = performs?['actions'];
    int? duration;

    String? foundBy;
    String? foundValue;
    for (Map<String, dynamic> action in actions) {
      final f = action['foundBy'] as String?;
      if (f != null  && f.isNotEmpty) {
        foundBy = f;
      }
      final v = action['value'] as String?;
      if (v != null && v.isNotEmpty) {
        foundValue = v;
      }
    }

    int? x;
    int? y;
    int? x2;
    int? y2;
    for (Map<String, dynamic> action in actions) {
      //Result? response;
      //Map<String, dynamic>? response;
      var type = action['type'];
      switch (type) {
        case "pointerMove":
          if (x != null) {
            x2 = action['x'];
            duration = action['duration'];
          } else {
            x = action['x'];
          }
          if (y != null) {
            y2 = action['y'];
          } else {
            y = action['y'];
          }
          break;
        case "pointerDown":
          break;
        case "pause":
          duration = action['duration'];
          break;
        case "pointerUp":
          final node = _getNodeFromOffset(
              Offset(x!.toDouble(), y!.toDouble()));
          if (node != null) {
            Map<String, dynamic>? result;
            if ((x2 != null && x != x2) || (y2 != null && y != y2)) {
              result = await _execCommandWithFinder(
                  x, y, node, "scroll", duration: duration, dx: x2! - x, dy: y2! - y);
            } else {
              result = await _execCommandWithFinder(
                  x, y, node, "tap", duration: duration);
            }
            if (!result?['isError']) {
              sleep(const Duration(seconds: 1));
              return '{"text":"${node.getAttribute("text")}","elementId":"${node.getAttribute("id")}","type":"${node.getAttribute("class")}","foundBy":"${result?['foundBy']}","value":"${result?['value']}"}';
            }
          } else {
            sendMail(subject: "not found", body: "x = $x, y = $y");
          }
          break;
        case "enterText":
          final node = _getNodeFromOffset(
              Offset(x!.toDouble(), y!.toDouble()));
          final result = await _execCommandWithFinder(x, y, node!, "enter_text", enterText: action['text'], foundBy: foundBy, value: foundValue);
          if (!result?['isError']) {
            sleep(const Duration(seconds: 1));
            return '{"text":"${node.getAttribute("text")}","elementId":"${node
                .getAttribute("id")}","type":"${node.getAttribute("class")}","foundBy":"${result?['foundBy']}","value":"${result?['value']}"}';
          }
          break;
        case "checkText":
          final node = _getNodeFromOffset(
              Offset(x!.toDouble(), y!.toDouble()));
          final result = await _execCommandWithFinder(x, y, node!, "check_text", enterText: action['text'], foundBy: foundBy, value: foundValue);
          if (!result?['isError']) {
            return '{"text":"${node.getAttribute("text")}","elementId":"${node
                .getAttribute("id")}","type":"${node.getAttribute("class")}","foundBy":"${result?['foundBy']}","value":"${result?['value']}"}';
          }
          break;
        case "checkExistence":
          final node = _getNodeFromOffset(
              Offset(x!.toDouble(), y!.toDouble()));
          final result = await _execCommandWithFinder(x, y, node!, "check_existence", enterText: '', foundBy: foundBy, value: foundValue);
          if (!result?['isError']) {
            return '{"text":"${node.getAttribute("text")}","elementId":"${node
                .getAttribute("id")}","type":"${node.getAttribute("class")}","foundBy":"${result?['foundBy']}","value":"${result?['value']}"}';
          }
          break;
      }
    }
    return "{}";
  }

  Future<Map<String, dynamic>?> _execCommandWithFinder(int x, int y, XmlNode node, String command,
      {String? enterText, int? duration, int? dx, int? dy, String? foundBy, String? value}) async {
    if (foundBy != null && foundBy == 'byToolTip') {
      return await _driveTooltip(command, value!, dx: dx, dy: dy);
    }
    final tooltip = await _findNodeTooltip(
        Offset(x.toDouble(), y.toDouble()), node);
    if (tooltip != null && tooltip.isNotEmpty) {
      return _driveTooltip(command, tooltip, dx: dx, dy: dy);
    }
    if (foundBy != null && foundBy == "bySemanticsLabel") {
      return _driveSemanticLabel(command, value!, enterText:enterText, duration: duration, dx: dx, dy: dy);
    }
    final semanticLabel = await _findNodeLabel(
        Offset(x.toDouble(), y.toDouble()), node);
    if (semanticLabel != null && semanticLabel.isNotEmpty) {
      return _driveSemanticLabel(command, value!, enterText:enterText, duration: duration, dx: dx, dy: dy);
    }
    if (foundBy != null && foundBy == "byValueKey") {
      return _driveKey(command, value!, enterText: enterText, duration: duration, dx: dx, dy: dy);
    }
    var key = node.getAttribute("key");
    if (key != null && key.isNotEmpty) {
      return _driveKey(command, key, enterText: enterText, duration: duration, dx: dx, dy: dy);
    }
    if (foundBy != null && foundBy == "byText") {
      return _driveText(command, value!, enterText: enterText, duration: duration, dx: dx, dy: dy);
    }
    final text = await _findNodeText(
        Offset(x.toDouble(), y.toDouble()), node);
    if (text != null && text.isNotEmpty) {
      return _driveText(command, text, enterText: enterText, duration: duration, dx: dx, dy: dy);
    }
    if (foundBy != null && foundBy == "byType") {
      return _driveType(command, value!, enterText: enterText, duration: duration, dx: dx, dy: dy);
    }
    final type = node.getAttribute('class');
    return _driveType(command, type!, enterText: enterText, duration: duration, dx: dx, dy: dy);
  }

  Future<Map<String, dynamic>?> _driveTooltip(String command, String tooltip, {int? duration, int? dx, int? dy}) async {
    if (command == "check_text" || command == 'check_existence') {
      Map<String, dynamic> result = {
        'isError': false,
        'foundBy': 'byTooltip',
        'value': tooltip
      };
      return result;
    } else {
      Map<String, String> params = {
        "command": command, "finderType": "ByTooltipMessage", "text": tooltip
      };
      if (dx != null && dy != null) {
        params['dx'] = dx.toString();
        params['dy'] = dy.toString();
      }
      if (duration != null) {
        params['duration'] = duration.toString();
      }
      if (command == 'scroll') {
        params['frequency'] = '60';
      }
      final result = await _driverExtension?.call(params);
      if (!result?['isError']) {
        result?['foundBy'] = 'byTooltip';
        result?['value'] = tooltip;
        return result;
      }
    }
    return {};
  }

  Future<Map<String, dynamic>?>_driveSemanticLabel(String command, String semanticLabel,
      {String? enterText, int? duration, int? dx, int? dy}) async {
    if (command == "check_text" || command == 'check_existence') {
      Map<String, dynamic> result = {
        'isError': false,
        'foundBy': 'bySemanticsLabel',
        'value': semanticLabel
      };
      return result;
    } else {
      Map<String, String> params = {
        "command": command,
        "finderType": "bySemanticsLabel",
        "label": semanticLabel
      };
      if (dx != null && dy != null) {
        params['dx'] = dx.toString();
        params['dy'] = dy.toString();
      }
      if (duration != null) {
        params['duration'] = duration.toString();
      }
      if (command == 'scroll') {
        params['frequency'] = '60';
      }
      if (command == "enter_text") {
        params['text'] = enterText!;
      } else if (command == 'tap' && duration != null) {
        params['duration'] = duration!.toString();
      }
      final result = await _driverExtension?.call(params);
      if (!result?['isError']) {
        result?['foundBy'] = 'bySemanticsLabel';
        result?['value'] = semanticLabel;
        return result;
      }
    }
    return {};
  }

  Future<Map<String, dynamic>?> _driveKey(String command, String key,
      {String? enterText, int? duration, int? dx, int? dy}) async {
    if (key.substring(0,3) == "[<'") {
      final end = key.indexOf("'>]");
      key = key.substring(3, end);
    } else if (key.substring(0,1) == "[") {
      final end = key.indexOf("]");
      key = key.substring(1, end);
    }

    if (command == "check_text" || command == 'check_existence') {
      Map<String, dynamic> result = {
        'isError': false,
        'foundBy': "byValueKey",
        'value': key
      };
      return result;
    } else {
      if (command == "enter_text") {
        Map<String, String> params = {
          "command": "set_text_entry_emulation",
          "finderType": "ByValueKey",
          "keyValueString": 'textfield',
          "keyValueType": "String",
          "enabled": "true"
        };
        await _driverExtension?.call(params);
      }

      Map<String, String> params = {
        "command": command,
        "finderType": "ByValueKey",
        "keyValueString": key,
        "keyValueType": "String"
      };
      if (dx != null && dy != null) {
        params['dx'] = dx.toString();
        params['dy'] = dy.toString();
      }
      if (duration != null) {
        params['duration'] = duration.toString();
      }
      if (command == 'scroll') {
        params['frequency'] = '60';
      }
      if (command == "enter_text") {
        params['text'] = enterText!;
      }
      final result = await _driverExtension?.call(params);
      if (!result?['isError']) {
        result?['foundBy'] = 'byValueKey';
        result?['value'] = key.toString();
      }
      return result;
    }
  }

  Future<Map<String, dynamic>?> _driveText(String command, String text,
      {String? enterText, int? duration, int? dx, int? dy}) async {
    if (command == "check_text" || command == 'check_existence') {
      Map<String, dynamic> result = {
        'isError': false,
        'foundBy': 'byText',
        'value': text
      };
      return result;
    } else {
      Map<String, String> params = {
        "command": command, "finderType": "ByText", "text": text
      };
      if (dx != null && dy != null) {
        params['dx'] = dx.toString();
        params['dy'] = dy.toString();
      }
      if (duration != null) {
        params['duration'] = duration.toString();
      }
      if (command == 'scroll') {
        params['frequency'] = '60';
      }
      if (command == "enter_text") {
        params['text'] = enterText!;
      }
      final result = await _driverExtension?.call(params);
      if (!result?['isError']) {
        result?['foundBy'] = 'byText';
        result?['value'] = text;
        return result;
      }
    }
    return {};
  }

  Future<Map<String, dynamic>?> _driveType(String command, String type,
      {String? enterText, int? duration, int? dx, int? dy}) async {
    if (command == "check_text" || command == 'check_existence') {
      Map<String, dynamic> result = {
        'isError': false,
        'foundBy': 'byType',
        'value': type
      };
      return result;
    } else {
      Map<String, String> params = {
        "command": command, "finderType": "ByType", "type": type!
      };
      if (dx != null && dy != null) {
        params['dx'] = dx.toString();
        params['dy'] = dy.toString();
      }
      if (duration != null) {
        params['duration'] = duration.toString();
      }
      if (command == 'scroll') {
        params['frequency'] = '60';
      }
      if (command == "enter_text") {
        params['text'] = enterText!;
      }
      final result = await _driverExtension?.call(params);
      result?['foundBy'] = 'byType';
      result?['value'] = type;
      return result;
    }
  }

  XmlElement? _findSizeRoot(XmlElement element) {
    var rect = _boundsToRect(element.getAttribute("bounds"));
    XmlElement? contained = element;
    while (contained?.parentElement != null) {
      final rct = _boundsToRect(
          contained?.parentElement?.getAttribute("bounds"));
      if (rect?.left == rct?.left && rect?.right == rct?.right) {
        contained = contained?.parentElement;
      } else {
        return contained;
      }
    }
    return contained;
  }

  Future<String?> _findNodeLabel(Offset pos, XmlNode node) async {
    try {
      final text = node.getAttribute("semanticLabel");
      if (text != null && text.isNotEmpty) {
        return text;
      }
      for (final element in node.childElements) {
        final text = await _findElementLabel(pos, element);
        if (text != null && text.isNotEmpty) {
          return text;
        }
      }
    } catch(e) {
      sendMail(subject:"NodeLabel exception", body: e.toString());
    }
    return null;
  }

  Future<String?> _findElementLabel(Offset pos, XmlElement element) async {
    var text = element.getAttribute("semanticLabel");
    if (text != null && text.isNotEmpty) {
      return text;
    }
    for (final element in element.childElements) {
      text = await _findElementLabel(pos, element);
      if (text != null && text.isNotEmpty) {
        return text;
      }
    }
    return null;
  }

  Future<String?> _findNodeText(Offset pos, XmlNode node) async {
    final text = node.getAttribute("text");
    if (text != null && text.isNotEmpty) {
      return text;
    }
    /*
    for (final element in node.childElements) {
      final text = await _findElementText(pos, element);
      if (text != null && text.isNotEmpty) {
        return text;
      }
    }
     */
    return null;
  }

  Future<String?> _findElementText(Offset pos, XmlElement element) async {
    var text = element.getAttribute("text");
    if (text != null && text.isNotEmpty) {
      return text;
    }
    for (final element in element.childElements) {
      text = await _findElementText(pos, element);
      if (text != null && text.isNotEmpty) {
        return text;
      }
    }
    return null;
  }

  Future<String?> _findNodeTooltip(Offset pos, XmlNode node) async {
    final text = node.getAttribute("tooltip");
    if (text != null && text.isNotEmpty) {
      return text;
    }
    /*
    for (final element in node.childElements) {
      final text = await _findElementTooltip(pos, element);
      if (text != null && text.isNotEmpty) {
        return text;
      }
    }
     */
    return null;
  }

  Future<String?> _findElementTooltip(Offset pos, XmlElement element) async {
    var text = element.getAttribute("tooltip");
    if (text != null && text.isNotEmpty) {
      return text;
    }
    for (final element in element.childElements) {
      text = await _findElementTooltip(pos, element);
      if (text != null && text.isNotEmpty) {
        return text;
      }
    }
    return null;
  }

  XmlNode? _getNodeFromOffset(Offset pos) {
    XmlNode? contained;
    Rect? rect;
    _document?.descendants.toList().reversed.forEach((node) {
      var bounds = node.getAttribute("bounds");
      if (bounds != null) {
        rect = _boundsToRect(bounds);
        if (contained == null && rect!.contains(pos)) {
          contained = node;
        }
      }
    });
    return contained;
  }

  Rect? _boundsToRect(String? bounds) {
    final leftRight = bounds?.split("][");
    final topLeft = leftRight?[0].split(',');
    final left = topLeft?[0].substring(1);
    final top = topLeft?[1];
    final bottomRight = leftRight?[1].split(',');
    final right = bottomRight?[0];
    final bottom = bottomRight?[1].substring(0, bottomRight[1].length - 1);
    return Rect.fromLTRB(
        double.parse(left!), double.parse(top!), double.parse(right!),
        double.parse(bottom!));
  }

  sendMail({String? subject, String? body}) async {
    var stackTrace = StackTrace.current;
    final Email email = Email(
      body: body ?? "",
      subject: subject ?? "",
      recipients: ['mhori@baleen.studio'],
      cc: [],
      bcc: [],
      attachmentPaths: [],
      isHTML: false,
    );
    await FlutterEmailSender.send(email);
  }
}
