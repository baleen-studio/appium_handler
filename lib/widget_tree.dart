import 'dart:developer';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/src/foundation/diagnostics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'devtools_app/initialization.dart';
import 'devtools_app/main.dart';
import 'devtools_app/src/framework/framework_core.dart';
import 'devtools_app/src/screens/debugger/syntax_highlighter.dart';
import 'devtools_app/src/screens/inspector/inspector_controller.dart';
import 'devtools_app/src/screens/inspector/inspector_screen.dart';
import 'devtools_app/src/screens/inspector/inspector_tree_controller.dart';
import 'devtools_app/src/shared/analytics/metrics.dart';
import 'devtools_app/src/shared/console/eval/inspector_tree.dart';
import 'devtools_app/src/shared/console/primitives/simple_items.dart';
import 'devtools_app/src/shared/environment_parameters/environment_parameters_base.dart';
import 'devtools_app/src/shared/environment_parameters/environment_parameters_external.dart';
import 'devtools_app/src/shared/globals.dart';
import 'devtools_app/src/shared/primitives/utils.dart';
import 'devtools_app/src/shared/screen.dart';
import 'devtools_app/src/shared/utils.dart';
import 'devtools_app_shared/src/utils/globals.dart';
import 'devtools_shared/src/service_utils.dart';
import 'package:provider/provider.dart' as provider;

class MyInspectorController /*extends State<MyHomeState>
    with ProvidedControllerMixin<InspectorController, MyHomeState>*/ {

  MyInspectorController();
  DevToolsScreen<InspectorController>? devScreen;

  Future<InspectorTreeNode?> getRootNode(/*BuildContext context*/) async {
    //initializeFramework();
    //InspectorController controller = provider.Provider.of<InspectorController>(context, listen: false);

    await initializeDevTools(
      integrationTestMode: integrationTestMode,
      shouldEnableExperiments: false, //shouldEnableExperiments,
    );

    // Load the Dart syntax highlighting grammar.
    await SyntaxHighlighter.initialize();

    setGlobal(
      DevToolsEnvironmentParameters,
      ExternalDevToolsEnvironmentParameters(),
    );

    final info = await Service.getInfo();
    //final routerDelegate = DevToolsRouterDelegate.of(AppiumHandler().buildContext!);
    final connected =
        await FrameworkCore.initVmService(serviceUriAsString: info.serverUri.toString(), logException: false, errorReporter: (String title, Object error){
          debugPrint("$title: $error");
        });
    if (connected) {
      final connectedUri =
            Uri.parse(serviceConnection.serviceManager.serviceUri!);
      //routerDelegate.updateArgsIfChanged({'uri': '$connectedUri'});
      final shortUri = connectedUri.replace(path: '');
      notificationService.push('Successfully connected to $shortUri.');
    } else if (normalizeVmServiceUri(info.serverUri.toString()) == null) {
      notificationService.push(
        'Failed to connect to the VM Service at "_init".\n'
            'The link was not valid.',
      );
    }

    final inspector = InspectorController(
      inspectorTree: InspectorTreeController(
        gaId: InspectorScreenMetrics.summaryTreeGaId,
      ),
      detailsTree: InspectorTreeController(
        gaId: InspectorScreenMetrics.detailsTreeGaId,
      ),
      treeType: FlutterTreeType.widget,
    );

    devScreen = DevToolsScreen<InspectorController>(
      InspectorScreen(),
      createController: (_) => inspector/*InspectorController(
        inspectorTree: InspectorTreeController(
          gaId: InspectorScreenMetrics.summaryTreeGaId,
        ),
        detailsTree: InspectorTreeController(
          gaId: InspectorScreenMetrics.detailsTreeGaId,
        ),
        treeType: FlutterTreeType.widget,
      ),
      */
    );

    inspector.recomputeTreeRoot(null, null, false,
      subtreeDepth: maxJsInt,
    );

    //controller.inspectorTree.setupInspectorTreeNode(controller.inspectorTree.root!, controller.inspectorTree.root!.diagnostic!, expandChildren: true, expandProperties: false);
    //controller.waitForPendingUpdateDone();

    return null;
  }
}

class MyInspectorScreenBody extends StatefulWidget {
  const MyInspectorScreenBody({super.key});

  @override
  MyInspectorScreenBodyState createState() => MyInspectorScreenBodyState();
}

class MyInspectorScreenBodyState extends State<MyInspectorScreenBody>
    with
        ProvidedControllerMixin<InspectorController, MyInspectorScreenBody> {

  @override
  Widget build(BuildContext context) {
    initController();
    return View(view: View.of(context), child: const Scaffold());
  }
}