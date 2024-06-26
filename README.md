# Appium Flutter Driver Handler

_Appium Flutter Driver_ から呼び出されるコールバック関数。  
テスト対象アプリにリンクする必要がある。  
画面サイズの取得、画面イメージの取得、Widgetの操作等を行っている。  

## Getting Started

_flutter_driver_ 初期化時に登録する。

```dart:main.dart
import 'package:appium_handler/appium_handler.dart';

void main() {
  var handler = AppiumHandler();
  enableFlutterDriverExtension(
    handler: handler.appiumHandler,
    notifier: handler.initNotifier,
  );
  handler.buildDriverExtension();
  runApp(MyApp());
}
```

