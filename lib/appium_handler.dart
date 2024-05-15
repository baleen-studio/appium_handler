library appium_handler;

import 'dart:convert';
import 'dart:io';
import 'dart:developer';
import 'dart:isolate';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:xml/xml.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:test/test.dart';
import 'package:flutter_driver/flutter_driver.dart';

/// A Calculator.
class AppiumHandler {
  static final AppiumHandler _instance = AppiumHandler._internal();

  factory AppiumHandler() {
    return _instance;
  }

  AppiumHandler._internal();

  /// Returns [value] plus 1.
  int addOne(int value) => value + 1;

  //Widget? _myApp;
  //PackageInfo? _packageInfo;
  int _index = 0;
  String _source = "";
  //String? _driverUrl;
  final jsonEncoder = const JsonEncoder();
  //FlutterDriver? _driver;
  BuildContext? _context;
  XmlDocument? _document;
  FlutterDriverExtension? _driverExtension;
  bool _isInTest = false;
  var uuid = const Uuid();
  final _receivePort = ReceivePort();
  final _visiblityDetectorrController = VisibilityDetectorController();

  //set myApp(StatelessWidget app) {
  //  _myApp = app;
  //}
  BuildContext? get buildContext => _context;
  set buildContext(BuildContext? context) {
    _context = context;
  }

  /*
  RenderObject?  _renderObject(Element ele) {
    Element? current = ele;
    while (current != null) {
      if (current is RenderObjectElement) {
        return current.renderObject;
      } else {
        current = current.renderObjectAttachingChild;
      }
    }
    return null;
  }

  Future<String?> _getVmServiceUri() async {
    final results = await run('flutter --list-vms');
    for (final result in results) {
      if (result.exitCode != 0 || result.stdout == null) {
        return null;
      }
      final lines = result.stdout!.split('\n');
      for (final line in lines) {
        if (line.contains('Observatory listening on')) {
          final uri = line.split(' ').last;
          return uri;
        }
      }
    }
    return null;
  }

  VisibilityDetector _buildVisiblityDetector(Widget widget, {Key? key}) {
    return VisibilityDetector(
      key: widget.key ?? key!,
      onVisibilityChanged: (visibilityInfo) {
        var visiblePercentage = visibilityInfo.visibleFraction * 100;
        _sendMail(subject:"dartVmServiceUrl", body:
        'Widget ${visibilityInfo.key} is $visiblePercentage% visible');
      },
      child: widget,
    );
  }
   */

  Future<void> initNotifier(FlutterDriverExtension extension) async {
    _driverExtension = extension;
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
    var cmdAndArg = cmd?.split(':');
    var msg = cmdAndArg?[0]; //parts[1].trim();
    if (msg == 'getScreenSize') {
      // some call handling in the application]
      final deviceWidth = MediaQuery
          .of(_context!)
          .size
          .width
          .toInt();
      final deviceHeight = MediaQuery
          .of(_context!)
          .size
          .height
          .toInt();
      //final screenSize = WidgetsBinding.instance.window.physicalSize;
      return jsonEncode({'width': deviceWidth, 'height': deviceHeight});
    } else if (msg == 'getPageSource') {
      void visitor(Element element) {
        final renderObject = element.renderObject;  // _renderObject(element);
        String? key;
        if (element.widget.key == null) {
          key = "";
        } else {
          key = element.widget.key.toString();
        }
        var type = element.widget.runtimeType.toString()
            .replaceAll('<', '-')
            .replaceAll('>', '-');
        if (element.widget.key != null && element.widget.key.toString().isNotEmpty &&
            type.substring(0, 1) != '_' && !key.contains("GlobalKey") && !key.contains("GlobalObjectKey")) {
        //if (element.widget is Semantics) {
          var left = renderObject?.paintBounds.left;
          var top = renderObject?.paintBounds.top;
          var right = renderObject?.paintBounds.right;
          var bottom = renderObject?.paintBounds.bottom;

          RenderBox? renderBox;
          if (renderObject is RenderBox) {
            renderBox = renderObject;
          } else {
            renderBox = _context?.findRenderObject() as RenderBox;
          }
          Offset topLeft = renderBox.localToGlobal(Offset(left!, top!));
          Offset bottomRight = renderBox.localToGlobal(Offset(right!, bottom!));
          String? text = '';
          String? toolTip = '';
          String? pass = "false";
          try {
            (element.widget as dynamic).tooltip;
            toolTip = (element.widget as dynamic).tooltip as String;
          } on NoSuchMethodError {
            debugPrint("tooltip not included in ${element.widget.runtimeType.toString()}");
          }
          if (element.widget.runtimeType == Text) {
            text = (element.widget as Text).data;
          } else if (element.widget.runtimeType == RichText) {
            final RichText richText = element.widget as RichText;
            text = richText.text.toPlainText(
              includeSemanticsLabels: false,
              includePlaceholders: false,
            );
          } else if (element.widget.runtimeType == TextField) {
            pass = (element.widget as TextField).obscureText ? "true" : "false";
            text = (element.widget as TextField).controller?.text;
          } else if (element.widget.runtimeType == TextFormField) {
            text = (element.widget as TextFormField).controller?.text;
          } else if (element.widget.runtimeType == EditableText) {
            text = (element.widget as EditableText).controller.text;
          } else if (type == "Text") {
            text = (element.widget as Text).data;
          } else if (type == "RichText") {
            text = (element.widget as RichText).text.toPlainText(
              includeSemanticsLabels: false,
              includePlaceholders: false,
            );
          } else if (type == "TextField") {
            pass = (element.widget as TextField).obscureText ? "true" : "false";
            text = (element.widget as TextField).controller?.text;
          } else if (type == "Tooltip") {
            toolTip = (element.widget as Tooltip).message;
          }
          bool isEditable = (element.widget is TextField || element.widget is TextFormField);

          ++_index;
          _source =
          '$_source<$type id="${element.widget
              .hashCode}" key="$key" index="$_index" class="$type" text="$text" tooltip="$toolTip" password="$pass" bounds="[${topLeft
              //.hashCode}" key="$key" index="$_index" class="$type" text="$text" bounds="[${topLeft
              .dx.toInt()},${topLeft.dy.toInt()}][${bottomRight.dx
              .toInt()},${bottomRight.dy.toInt()}]" attached="${renderObject!
              .attached ? "true" : "false"}" input="${isEditable ? "true" : "false"}"';
          /*
          if (element.widget is Semantics) {
            try {
              if ((element.widget as Semantics).child != null) {
                _source +=
                ' child="${(element.widget as Semantics).child.runtimeType.toString()}"';
              }
              _source +=
              ' attributedHint="${(element.widget as Semantics).properties
                  .attributedHint ?? ""}"';
              _source +=
              ' attributedIncreasedValue="${(element.widget as Semantics)
                  .properties.attributedIncreasedValue ?? ""}"';
              _source +=
              ' attributedLabel="${(element.widget as Semantics).properties
                  .attributedLabel ?? ""}"';
              _source +=
              ' attributedValue="${(element.widget as Semantics).properties
                  .attributedValue ?? ""}"';
              if ((element.widget as Semantics).properties.button!=null) {
                _source +=
                ' button="${(element.widget as Semantics).properties.button!
                    ? "true"
                    : "false"}"';
              }
              if ((element.widget as Semantics).properties.checked != null) {
                _source +=
                ' checked="${(element.widget as Semantics).properties.checked!
                    ? "true"
                    : "false"}"';
              }
              _source +=
              ' currentValueLength="${(element.widget as Semantics).properties
                  .currentValueLength ?? ""}"';
              _source +=
              ' decreasedValue="${(element.widget as Semantics).properties
                  .decreasedValue ?? ""}"';
              if ((element.widget as Semantics).properties.enabled != null) {
                _source +=
                ' enabled="${(element.widget as Semantics).properties.enabled!
                    ? "true"
                    : "false"}"';
              }
              if ((element.widget as Semantics).properties.expanded != null) {
                _source +=
                ' expanded="${(element.widget as Semantics).properties.expanded!
                    ? "true"
                    : "false"}"';
              }
              if ((element.widget as Semantics).properties.focusable != null) {
                _source +=
                ' focusable="${(element.widget as Semantics).properties
                    .focusable!
                    ? "true"
                    : "false"}"';
              }
              if ((element.widget as Semantics).properties.focused != null) {
                _source +=
                ' focused="${(element.widget as Semantics).properties.focused!
                    ? "true"
                    : "false"}"';
              }
              if ((element.widget as Semantics).properties.header != null) {
                _source +=
                ' header="${(element.widget as Semantics).properties.header!
                    ? "true"
                    : "false"}"';
              }
              if ((element.widget as Semantics).properties.hidden != null) {
                _source +=
                ' hidden="${(element.widget as Semantics).properties.hidden!
                    ? "true"
                    : "false"}"';
              }
              _source +=
              ' hint="${(element.widget as Semantics).properties.hint ?? ""}"';
              _source +=
              ' identifier="${(element.widget as Semantics).properties
                  .identifier ?? ""}"';
              if ((element.widget as Semantics).properties.image != null) {
                _source +=
                ' image="${(element.widget as Semantics).properties.image!
                    ? "true"
                    : "false"}"';
              }
              _source += ' image="${(element.widget as Semantics).properties
                  .increasedValue ?? ""}"';
              if ((element.widget as Semantics).properties.inMutuallyExclusiveGroup != null) {
                _source +=
                ' inMutuallyExclusiveGroup="${(element.widget as Semantics)
                    .properties.inMutuallyExclusiveGroup! ? "true" : "false"}"';
              }
              if ((element.widget as Semantics).properties.keyboardKey != null) {
                _source +=
                ' keyboardKey="${(element.widget as Semantics).properties
                    .keyboardKey! ? "true" : "false"}"';
              }
              _source +=
              ' keyboardKey="${(element.widget as Semantics).properties
                  .label ?? ""}"';
              if ((element.widget as Semantics).properties.link != null) {
                _source +=
                ' link="${(element.widget as Semantics).properties.link!
                    ? "true"
                    : "false"}"';
              }
              if ((element.widget as Semantics).properties.liveRegion != null) {
                _source +=
                ' liveRegion="${(element.widget as Semantics).properties
                    .liveRegion! ? "true" : "false"}"';
              }
              if ((element.widget as Semantics).properties.multiline != null) {
                _source +=
                ' multiline="${(element.widget as Semantics).properties
                    .multiline!
                    ? "true"
                    : "false"}"';
              }
              if ((element.widget as Semantics).properties.namesRoute != null) {
                _source +=
                ' namesRoute="${(element.widget as Semantics).properties
                    .namesRoute! ? "true" : "false"}"';
              }
              if ((element.widget as Semantics).properties.obscured != null) {
                _source +=
                ' password="${(element.widget as Semantics).properties.obscured!
                    ? "true"
                    : "false"}"';
              } else {
                _source += ' password="$pass"';
              }
              if ((element.widget as Semantics).properties.readOnly != null) {
                _source +=
                ' readOnly="${(element.widget as Semantics).properties.readOnly!
                    ? "true"
                    : "false"}"';
              }
              if ((element.widget as Semantics).properties.scopesRoute != null) {
                _source +=
                ' scopesRoute="${(element.widget as Semantics).properties
                    .scopesRoute! ? "true" : "false"}"';
              }
              if ((element.widget as Semantics).properties.selected != null) {
                _source +=
                ' selected="${(element.widget as Semantics).properties.selected!
                    ? "true"
                    : "false"}"';
              }
              if ((element.widget as Semantics).properties.slider != null) {
                _source +=
                ' slider="${(element.widget as Semantics).properties.slider!
                    ? "true"
                    : "false"}"';
              }
              if ((element.widget as Semantics).properties.textField != null) {
                _source +=
                ' textField="${(element.widget as Semantics).properties
                    .textField!
                    ? "true"
                    : "false"}"';
              }
              _source +=
              ' tooltip="${(element.widget as Semantics).properties.tooltip ?? toolTip}"';
              _source +=
              ' value="${(element.widget as Semantics).properties.value ?? ""}"';
            } catch(e) {
              _sendMail(subject:"execption", body: "$e");
              return;
            }
          }
           */
          //_source += ' checkable="false" checked="false" clickable="true" enabled="true" focusable="true" focused="false" long-clickable="true" scrollable="false" selected="false" displayed="true" >\n';
          _source += '  >\n';
          element.visitChildren(visitor);
          _source += '</$type>\n';
          //  checkable="false" checked="false" clickable="true" enabled="true" focusable="true" focused="false" long-clickable="false" scrollable="false" selected="false" displayed="true"
        } else {
          element.visitChildren(visitor);
        }
      }
      _source = '<?xml version="1.0"?>\n';
      _source += "<tree>\n";
      //WidgetsFlutterBinding.ensureInitialized().rootElement?.visitChildren(visitor);
      visitor(WidgetsFlutterBinding.ensureInitialized().rootElement!);
      //WidgetsFlutterBinding.ensureInitialized().rootElement?.visitChildElements(visitor);
      //_context?.visitChildElements(visitor);
      _source += "</tree>\n";
      try {
        _document = XmlDocument.parse(_source);
        return _document.toString();
      } catch (e) {
        // Handle any exceptions thrown during decoding
        return _source;
      }
    } else if (msg == 'screenShot') {
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
    } else if (msg == 'performActions') {
      var idx = cmd?.indexOf(':');
      var json = cmd?.substring(idx! + 1).trim();
      try {
        // Attempt to decode the JSON string
        var jsonObject = jsonDecode(json!);
        if (jsonObject is List) {
          return await _performActions(jsonObject);
        }
        return "";
      } catch (e) {
        // Handle any exceptions thrown during decoding
        _sendMail(subject: "JSON decode", body: "Error decoding JSON: $e");
        return 'Error decoding JSON: $e';
      }
    } else if (msg == 'click') {
      var parts = cmdAndArg?[1].split(',');
      String? ret;
      _document?.descendants.toList().reversed.forEach((node) {
        var id = node.getAttribute("id");
        if (id == parts?[0]) {
          final str = node.getAttribute('class');
          Map<String, String> params = {
            "command":"tap","finderType":"ByType","type":str!
          };
          _driverExtension?.call(params).then((value) {
          });
          ret =
            '{"value":{"ELEMENT":"$id","element-6066-11e4-a52e-4f735466cecf":"$id"},"sessionId":"${parts?[1]}"}';
        }
      });
      return ret ?? "{}";
    } else if (msg == 'findElement') {
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
    }
    return jsonEncode({'width': msg, 'height': msg});
  }

  Future<String> _performActions(List<dynamic> jsonObject) async {
    Map<String, dynamic> performs = jsonObject[0];
    var type = performs['type'];
    var id = performs['id'];
    Map<String, dynamic> parameters = performs['parameters'];
    String? pointerType = parameters['pointerType'];
    List<dynamic> actions = performs['actions'];

    int? x;
    int? y;
    for (Map<String, dynamic> action in actions) {
      //Result? response;
      //Map<String, dynamic>? response;
      var type = action['type'];
      switch (type) {
        case "pointerMove":
          x = action['x'];
          y = action['y'];
          break;
        case "pointerDown":
          break;
        case "pause":
          sleep(Duration(milliseconds: action['duration']));
          break;
        case "pointerUp":
          bool tapped = false;
          final node = _getNodeFromOffset(
              Offset(x!.toDouble(), y!.toDouble()));
          if (node != null) {
            final result = await _execCommandWithFinder(x, y, node, "tap");
            if (!result?['isError']) {
              sleep(const Duration(seconds: 1));
              return '{"text":"${node.getAttribute("text")}","elementId":"${node.getAttribute("id")}","type":"${node.getAttribute("class")}"}';
            }
          } else {
            _sendMail(subject: "not found", body: "x = $x, y = $y");
          }
          break;
        case "enterText":
          final node = _getNodeFromOffset(
              Offset(x!.toDouble(), y!.toDouble()));
          final result = await _execCommandWithFinder(x, y, node!, "enter_text", enterText: action['text']);
          if (!result?['isError']) {
            sleep(const Duration(seconds: 1));
            return '{"text":"${node.getAttribute("text")}","elementId":"${node
                .getAttribute("id")}","type":"${node.getAttribute("class")}"}';
          }
          break;
      }
    }
    return "{}";
  }

  Future<Map<String, dynamic>?> _execCommandWithFinder(int x, int y, XmlNode node, String command, {String? enterText}) async {
    final text = _findNodeText(
        Offset(x.toDouble(), y.toDouble()), node);
    if (text != null && text.isNotEmpty) {
      Map<String, String> params = {
        "command":command,"finderType":"ByText","text":text
      };
      if (command == "enter_text") {
        params['text'] = enterText!;
      }
      final result = await _driverExtension?.call(params);
      if (!result?['isError']) {
        return result;
      }
    }
    final tooltip = _findNodeTooltip(
        Offset(x.toDouble(), y.toDouble()), node);
    if (tooltip != null && tooltip.isNotEmpty) {
      Map<String, String> params = {
        "command":command,"finderType":"ByTooltipMessage","text":tooltip
      };
      if (command == "enter_text") {
        params['text'] = enterText!;
      }
      final result = await _driverExtension?.call(params);
      if (!result?['isError']) {
        return result;
      }
    }
    final semanticLabel = _findNodeLabel(
        Offset(x.toDouble(), y.toDouble()), node);
    if (semanticLabel != null && semanticLabel.isNotEmpty) {
      Map<String, String> params = {
        "command":command,"finderType":"BySemanticsLabel","label":semanticLabel
      };
      if (command == "enter_text") {
        params['text'] = enterText!;
      }
      final result = await _driverExtension?.call(params);
      if (!result?['isError']) {
        return result;
      }
    }
    final key = node.getAttribute("key");
    if (key != null && key.isNotEmpty) {
      Map<String, String> params = {
        "command":"tap","finderType":"ByValueKey","keyValueString":key.toString(),"keyValueType":"String"
      };
      if (command == "enter_text") {
        params['text'] = enterText!;
      }
      final result = await _driverExtension?.call(params);
      if (!result?['isError']) {
        return result;
      }
    }
    final str = node.getAttribute('class');
    Map<String, String> params = {
      "command":"tap","finderType":"ByType","type":str!
    };
    if (command == "enter_text") {
      params['text'] = enterText!;
    }
    return await _driverExtension?.call(params);
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

  String? _findNodeLabel(Offset pos, XmlNode node) {
    final text = node.getAttribute("semanticLabel");
    if (text != null && text.isNotEmpty) {
      return text;
    }
    for (final element in node.childElements) {
      final text = _findElementLabel(pos, element);
      if (text != null && text.isNotEmpty) {
        return text;
      }
    }
    return null;
  }

  String? _findElementLabel(Offset pos, XmlElement element) {
    var text = element.getAttribute("semanticLabel");
    if (text != null && text.isNotEmpty) {
      return text;
    }
    for (final element in element.childElements) {
      text = _findElementLabel(pos, element);
      if (text != null && text.isNotEmpty) {
        return text;
      }
    }
    return null;
  }

  String? _findNodeText(Offset pos, XmlNode node) {
    final text = node.getAttribute("text");
    if (text != null && text.isNotEmpty) {
      return text;
    }
    for (final element in node.childElements) {
      final text = _findElementText(pos, element);
      if (text != null && text.isNotEmpty) {
        return text;
      }
    }
    return null;
  }

  String? _findElementText(Offset pos, XmlElement element) {
    var text = element.getAttribute("text");
    if (text != null && text.isNotEmpty) {
      return text;
    }
    for (final element in element.childElements) {
      text = _findElementText(pos, element);
      if (text != null && text.isNotEmpty) {
        return text;
      }
    }
    return null;
  }

  String? _findNodeTooltip(Offset pos, XmlNode node) {
    final text = node.getAttribute("tooltip");
    if (text != null && text.isNotEmpty) {
      return text;
    }
    for (final element in node.childElements) {
      final text = _findElementTooltip(pos, element);
      if (text != null && text.isNotEmpty) {
        return text;
      }
    }
    return null;
  }

  String? _findElementTooltip(Offset pos, XmlElement element) {
    var text = element.getAttribute("tooltip");
    if (text != null && text.isNotEmpty) {
      return text;
    }
    for (final element in element.childElements) {
      text = _findElementTooltip(pos, element);
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

  _sendMail({String? subject, String? body}) async {
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
