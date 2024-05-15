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
  runApp(MyApp());
}
```

元々の _enableFlutterDriverExtension_ 関数には _notifier_ という引数はないが、  
_flutter_driver_ に手を入れてある。  
目的は、 _FlutterDriverExtension_ クラスのインスタンスの作成を知るため。  
_FlutterDriverExtension_ を使い、アプリに __tap__ や __enter_text__ 等の動作を実行させる。  

これらの処理は _Appium Flutter Driver_ 側に実装できそうなので、後々そちらに移動予定。
