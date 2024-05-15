# Appium Flutter Driver Handler

_Appium Flutter Driver_から呼び出されるコールバック関数。
テスト対象アプリにリンクする必要がある。
画面サイズの取得、画面イメージの取得、Widgetの操作等を行っている。

## Getting Started

_flutter_driver_初期化時に登録する。

```dart:main.dart
import 'package:appium_handler/appium_handler.dart';

void main() {
  var handler = AppiumHandler();
  enableFlutterDriverExtension(
    handler: handler.appiumHandler,
    notifier: handler.initNotifier,
  );
  runApp(MyApp());
}
```

元々の_enableFlutterDriverExtension_関数には_notifier_という引数はないが、
_flutter_driver_に手を入れてある。
目的は、_FlutterDriverExtension_クラスのインスタンスの作成を知るため。
_FlutterDriverExtension_を使い、アプリに__tap__や__enter_text__等の動作を実行させる。

これらの処理は_Appium Flutter Driver_側に実装できそうなので、後々そちらに移動予定。
