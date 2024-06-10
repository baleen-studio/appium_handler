import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:flutter_driver/flutter_driver.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_email_sender/flutter_email_sender.dart';

/// The class that manages communication between a Flutter Driver test and the
/// application being remote-controlled, on the application side.
///
/// This is not normally used directly. It is instantiated automatically when
/// calling [enableFlutterDriverExtension].
class MyDriverExtension with DeserializeFinderFactory, CreateFinderFactory, DeserializeCommandFactory, CommandHandlerFactory {
  /// Creates an object to manage a Flutter Driver connection.
  MyDriverExtension(
      this._requestDataHandler,
      this._silenceErrors,
      this._enableTextEntryEmulation, {
        List<FinderExtension> finders = const <FinderExtension>[],
        List<CommandExtension> commands = const <CommandExtension>[],
      }) {
    if (_enableTextEntryEmulation) {
      registerTextInput();
    }

    for (final FinderExtension finder in finders) {
      _finderExtensions[finder.finderType] = finder;
    }

    for (final CommandExtension command in commands) {
      _commandExtensions[command.commandKind] = command;
    }
  }

  final WidgetController _prober = LiveWidgetController(WidgetsBinding.instance);
  WidgetController get prober => _prober;

  final DataHandler? _requestDataHandler;

  final bool _silenceErrors;

  final bool _enableTextEntryEmulation;

  void _log(String message) {
    driverLog('FlutterDriverExtension', message);
  }

  final Map<String, FinderExtension> _finderExtensions = <String, FinderExtension>{};
  final Map<String, CommandExtension> _commandExtensions = <String, CommandExtension>{};

  /// Processes a driver command configured by [params] and returns a result
  /// as an arbitrary JSON object.
  ///
  /// [params] must contain key "command" whose value is a string that
  /// identifies the kind of the command and its corresponding
  /// [CommandDeserializerCallback]. Other keys and values are specific to the
  /// concrete implementation of [Command] and [CommandDeserializerCallback].
  ///
  /// The returned JSON is command specific. Generally the caller deserializes
  /// the result into a subclass of [Result], but that's not strictly required.
  //@visibleForTesting
  Future<Map<String, dynamic>> call(Map<String, String> params) async {
    final String commandKind = params['command']!;
    try {
      final Command command = deserializeCommand(params, this);
      assert(WidgetsBinding.instance.isRootWidgetAttached || !command.requiresRootWidgetAttached,
      'No root widget is attached; have you remembered to call runApp()?');
      Future<Result> responseFuture = handleCommand(command, _prober, this);
      if (command.timeout != null) {
        responseFuture = responseFuture.timeout(command.timeout!);
      }
      final Result result = await responseFuture;
      final json = result.toJson();
      final response = _makeResponse(json);
      return response;
    } on TimeoutException catch (error, stackTrace) {
      final String message = 'Timeout while executing $commandKind: $error\n$stackTrace';
      _log(message);
      return _makeResponse(message, isError: true);
    } catch (error, stackTrace) {
      final String message = 'Uncaught extension error while executing $commandKind: $error\n$stackTrace';
      if (!_silenceErrors) {
        _log(message);
      }
      return _makeResponse(message, isError: true);
    }
  }

  Map<String, dynamic> _makeResponse(dynamic response, { bool isError = false }) {
    return <String, dynamic>{
      'isError': isError,
      'response': response,
    };
  }

  @override
  SerializableFinder deserializeFinder(Map<String, String> json) {
    final String? finderType = json['finderType'];
    if (_finderExtensions.containsKey(finderType)) {
      return _finderExtensions[finderType]!.deserialize(json, this);
    }

    return super.deserializeFinder(json);
  }

  @override
  Finder createFinder(SerializableFinder finder) {
    final String finderType = finder.finderType;
    if (_finderExtensions.containsKey(finderType)) {
      return _finderExtensions[finderType]!.createFinder(finder, this);
    }

    return super.createFinder(finder);
  }

  @override
  Command deserializeCommand(Map<String, String> params, DeserializeFinderFactory finderFactory) {
    final String? kind = params['command'];
    if (_commandExtensions.containsKey(kind)) {
      return _commandExtensions[kind]!.deserialize(params, finderFactory, this);
    }

    return super.deserializeCommand(params, finderFactory);
  }

  @override
  @protected
  DataHandler? getDataHandler() {
    return _requestDataHandler;
  }

  @override
  Future<Result> handleCommand(Command command, WidgetController prober, CreateFinderFactory finderFactory) {
    final String kind = command.kind;
    if (_commandExtensions.containsKey(kind)) {
      return _commandExtensions[kind]!.call(command, prober, finderFactory, this);
    }

    return super.handleCommand(command, prober, finderFactory);
  }
}
