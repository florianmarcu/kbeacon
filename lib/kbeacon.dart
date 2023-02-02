
import 'dart:async';

import 'package:flutter/services.dart';


class Kbeacon {
  static const MethodChannel _methodChannel = MethodChannel('kbeaconMethodChannel');
  static const EventChannel _eventChannel = EventChannel('kbeaconEventChannel');

  // static Stream<String> get availableDevices async*{
  //   await for (String message in _eventChannel.receiveBroadcastStream().map((event) => event)){
  //     yield message;
  //   }
  // } 

  static Stream<String> get buttonClickEvents async*{
    await for (String message in _eventChannel.receiveBroadcastStream().map((event) => event)){
      yield message;
    }
  } 

  static Future<String?> get platformVersion async {
    final String? version = await _methodChannel.invokeMethod('getPlatformVersion');
    return version;
  }

  static Future<String> initPlugin() async{
    final result = await _methodChannel.invokeMethod('initPlugin');
    return result;
  }

  static Future<String> startScanning() async{
    final result = await _methodChannel.invokeMethod('startScanning');
    return result;
  }

  static Future<String> connect(String macAddress) async{
    final result = await _methodChannel.invokeMethod('connect', {"macAddress": macAddress});
    return result;
  }

  static Future<String> disconnect(String macAddress) async{
    final result = await _methodChannel.invokeMethod('disconnect', {"macAddress": macAddress});
    return result;
  }

  static Future<String> enableButtonTrigger(String macAddress) async{
    final result = await _methodChannel.invokeMethod('enableButtonTrigger', {"macAddress": macAddress});
    return result;
  }

  static Future<void> requestCoarseLocationPermission() async{
    final result = await _methodChannel.invokeMethod('requestCoarseLocationPermission');
    return result;
  }

  static Future<void> requestFineLocationPermission() async{
    final result = await _methodChannel.invokeMethod('requestFineLocationPermission');
    return result;
  }

  static Future<void> requestBluetoothScanPermission() async{
    final result = await _methodChannel.invokeMethod('requestBluetoothScanPermission');
    return result;
  }

  static Future<void> requestBluetoothConnectionPermission() async{
    final result = await _methodChannel.invokeMethod('requestBluetoothConnectionPermission');
    return result;
  }
  
}
