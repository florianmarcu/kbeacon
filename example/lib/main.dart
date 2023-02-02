import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
// import 'package:flutter_ble_lib/flutter_ble_lib.dart' as ble;
import 'package:kbeacon/kbeacon.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:kbeacon_example/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_android/shared_preferences_android.dart';
import 'package:shared_preferences_ios/shared_preferences_ios.dart';
import 'package:workmanager/workmanager.dart';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';





void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  // await Kbeacon.requestFineLocationPermission(); 
  // await Kbeacon.requestCoarseLocationPermission();
  /// TODO: Need to handle the situation in which the user has his bluetooth turned off 
  // await Kbeacon.requestBluetoothScanPermission();
  // await Kbeacon.requestBluetoothConnectionPermission();
  // await Kbeacon.initPlugin();
  //var result  = await Kbeacon.startScanning();
  // Kbeacon.availableDevices.listen((event) {print("event ${event}");});
  // print(result);
  await config();

  runApp(const MyApp());
}

Future<void> config() async{
  await Firebase.initializeApp();
  // await Workmanager().initialize(
  //   callbackDispatcher, // The top level function, aka callbackDispatcher
  //   isInDebugMode: kDebugMode // If enabled it will post a notification whenever the task is running. Handy for debugging tasks
  // );
  // Workmanager().registerOneOffTask("task-identifier", "simpleTask",initialDelay: Duration(seconds: 10));


  // ble.BleManager bleManager = ble.BleManager();
  // await bleManager.createClient(); //ready to go! 

  final service = FlutterBackgroundService();

  /// FOR LOCAL NOTIFICATIONS ONLY
  // final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  //     FlutterLocalNotificationsPlugin();
  // if (Platform.isIOS) {
  //   await flutterLocalNotificationsPlugin.initialize(
  //     const InitializationSettings(
  //       iOS: IOSInitializationSettings(),
  //     ),
  //   );
  // }

  await service.configure(
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ), 
    androidConfiguration: AndroidConfiguration(
      onStart: onStart, 
      autoStart: true,
      autoStartOnBoot: true,
      isForegroundMode: true
    )
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  // WidgetsFlutterBinding.ensureInitialized();
  // DartPluginRegistrant.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  SharedPreferences preferences = await SharedPreferences.getInstance();
  await preferences.reload();
  final log = preferences.getStringList('log') ?? <String>[];
  log.add(DateTime.now().toIso8601String());
  await preferences.setStringList('log', log);

  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await FirebaseFirestore.instance.collection('logs').doc().set({"opened": true});
  print("START");
  
  // if(Platform.isAndroid) SharedPreferencesAndroid.registerWith();
  // if(Platform.isIOS) SharedPreferencesIOS.registerWith();
  // // SharedPreferences.setMockInitialValues({});
  // var sharedPreferances = await SharedPreferences.getInstance();
  // await sharedPreferances.reload();



  // String? macAddress = sharedPreferances.getString("macAddress");
  var macAddress = await FirebaseFirestore.instance.collection('config').doc('config').get().then((doc) => doc.data()!['mac_address']);
  print(macAddress);
  if(macAddress != null) {
    if(await Kbeacon.connect(macAddress) == "connected"){
      await Future.delayed(Duration(milliseconds: 5000));
      Kbeacon.enableButtonTrigger(macAddress);
      Kbeacon.buttonClickEvents.listen((event) {
        FirebaseFirestore.instance.collection('logs').doc(Timestamp.now().toString()).set({
          "date_created": FieldValue.serverTimestamp()
        });
      });
    }
  }

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  } 

  service.on('stopService').listen((event) async{
    await FirebaseFirestore.instance.collection('logs').doc('stopped').set({
      "date_stopped": FieldValue.serverTimestamp()
    });
    service.stopSelf();
  });

  // bring to foreground
  Timer.periodic(const Duration(seconds: 1), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        /// OPTIONAL for use custom notification
        /// the notification id must be equals with AndroidConfiguration when you call configure() method.
        // flutterLocalNotificationsPlugin.show(
        //   888,
        //   'COOL SERVICE',
        //   'Awesome ${DateTime.now()}',
        //   const NotificationDetails(
        //     android: AndroidNotificationDetails(
        //       'my_foreground',
        //       'MY FOREGROUND SERVICE',
        //       icon: 'ic_bg_service_small',
        //       ongoing: true,
        //     ),
        //   ),
        // );

        // if you don't using custom notification, uncomment this
        service.setForegroundNotificationInfo(
          title: "My App Service",
          content: "Updated at ${DateTime.now()}",
        );
      }
    }

    /// you can see this log in logcat
    print('FLUTTER BACKGROUND SERVICE: ${DateTime.now()}');

    // test using external plugin
    final deviceInfo = DeviceInfoPlugin();
    String? device;
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      device = androidInfo.model;
    }

    if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      device = iosInfo.model;
    }

    service.invoke(
      'update',
      {
        "current_date": DateTime.now().toIso8601String(),
        "device": device,
      },
    );
  });  
  print("START2");
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) {
    print("Native called background task: 1"); //simpleTask will be emitted here.
    return Future.value(true);
  }); 
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';

  @override
  void initState() {
    super.initState();
    // (SharedPreferences.getInstance()).then((instance) => print(instance.getString("macAddress")));
    // FlutterBlue.instance.startScan();
    Kbeacon.buttonClickEvents.listen((event) {print("1");});
    initPlatformState();
  }

  @override
  void dispose() {
    super.dispose();
    FlutterBlue.instance.stopScan();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion;
    // Platform messages may fail, so we use a try/catch PlatformException.
    // We also handle the message potentially returning null.
    try {
      platformVersion =
          await Kbeacon.platformVersion ?? 'Unknown platform version';
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  Future<void> registerDeviceLocally(String macAddress) async{
    var sharedPreferences = await SharedPreferences.getInstance();
    sharedPreferences.setString("macAddress", macAddress);
  }

  @override
  Widget build(BuildContext context) {
    //var provider = context.watch<DevicesPageProvider>();
    return MaterialApp(
      home: Scaffold(
        body: StreamBuilder<BluetoothState>(
          stream: FlutterBlue.instance.state,
          initialData: BluetoothState.unknown,
          builder: (context, ss) {
            if(!ss.hasData)
              return CircularProgressIndicator();
            else {
              
              return Center(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    Text("${ss.data}"),
                    /// Connected devices
                    StreamBuilder<List<BluetoothDevice>>(
                      stream: Stream.periodic(Duration(seconds: 2))
                          .asyncMap((_) => FlutterBlue.instance.connectedDevices),
                      initialData: [],
                      builder: (c, snapshot) => Column(
                        children: snapshot.data!
                          .map((d) => ListTile(
                                title: Text(d.name),
                                subtitle: Text(d.id.toString()),
                                trailing: StreamBuilder<BluetoothDeviceState>(
                                  stream: d.state,
                                  initialData: BluetoothDeviceState.disconnected,
                                  builder: (c, snapshot) {
                                    if (snapshot.data ==
                                        BluetoothDeviceState.connected) {
                                      // Kbeacon.enableButtonTrigger(d.id.toString());
                                      return TextButton(
                                        child: Text('OPEN'),
                                        onPressed: () {
                                          // Kbeacon.enableButtonTrigger(d.id.toString());
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                                builder: (context) =>
                                                    DeviceScreen(device: d)));}
                                      );
                                    }
                                    return Text(snapshot.data.toString());
                                  },
                                ),
                              ))
                          .toList(),
                      ),
                    ),
                    /// Available devices
                    StreamBuilder<List<ScanResult>>(
                      stream: FlutterBlue.instance.scanResults,
                      initialData: [],
                      builder: (c, snapshot) => Column(
                        children: snapshot.data!
                          .map<Widget>(
                            (r) => ScanResultTile(
                              result: r,
                              onTap: () async{
                                print(r.device.id);
                                await Kbeacon.connect(r.device.id.toString());
                                await FirebaseFirestore.instance.collection("config").doc("config").set({
                                  "mac_address": r.device.id.toString()
                                });
                                await registerDeviceLocally(r.device.id.toString()).then((e) => print("GATA"));
                                await Future.delayed(Duration(milliseconds: 5000));
                                await Kbeacon.enableButtonTrigger(r.device.id.toString()).then((value) => print(value));
                              },
                              // onTap: () => Navigator.of(context)
                              //     .push(MaterialPageRoute(builder: (context) {
                              //   r.device.connect();
                              //   return DeviceScreen(device: r.device);
                              // })),
                            ),
                          )
                          .toList(),
                      ),
                    ),
                    // ListView(
                    //   shrinkWrap: true,
                    //   children: provider.devices.map((device) => Container(
                    //     child: Text(
                    //       device.toString()
                    //     ),
                    //   )).toList(),
                    // )
                  ],
                ),
              );
            }
          }
        ),
      ),
    );
  }
}

class DeviceScreen extends StatelessWidget {
  const DeviceScreen({Key? key, required this.device}) : super(key: key);

  final BluetoothDevice device;

  List<int> _getRandomBytes() {
    final math = Random();
    return [

      // math.nextInt(255),
      // math.nextInt(255),
      // math.nextInt(255),
      // math.nextInt(255)
    ];
  }

  List<Widget> _buildServiceTiles(List<BluetoothService>? services) {
    print(services.toString() + " services");
    return services!
        .map(
          (service) {
            print(service.uuid);
            // print("\n");
            print(service.characteristics.length);
            // print("\n");
            service.characteristics.forEach((characteristic) async{ 
              // print("characteristic service uuuid: " + characteristic.serviceUuid.toString());
              await characteristic.setNotifyValue(true);
              print("read: " + characteristic.properties.read.toString());
              print("notify: " + characteristic.properties.notify.toString());
              print("write: " + characteristic.properties.write.toString());
              characteristic.value.listen((event) { print("VALUE: " + event.toString());});
            });
            return Container();
            // print("device id " + s.characteristics[0]);
            return ServiceTile(
            service: service,
            characteristicTiles: service.characteristics
                .map(
                  (c) => CharacteristicTile(
                    characteristic: c,
                    onReadPressed: () => c.read().then((value) => print("PUSH $value")),
                    onWritePressed: () async {
                      // await c.write(_getRandomBytes(), withoutResponse: true);
                      // await c.read();
                    },
                    onNotificationPressed: () async {
                      await c.setNotifyValue(!c.isNotifying);
                      await c.read();
                    },
                    descriptorTiles: c.descriptors
                        .map(
                          (d) => DescriptorTile(
                            descriptor: d,
                            onReadPressed: () => d.read(),
                            // onWritePressed: () => d.write(_getRandomBytes()),
                            onWritePressed: (){},
                          ),
                        )
                        .toList(),
                  ),
                )
                .toList(),
          );
          },
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(device.name),
        actions: <Widget>[
          StreamBuilder<BluetoothDeviceState>(
            stream: device.state,
            initialData: BluetoothDeviceState.connecting,
            builder: (c, snapshot) {
              VoidCallback? onPressed;
              String text;
              switch (snapshot.data) {
                case BluetoothDeviceState.connected:
                  // onPressed = () => device.disconnect();
                  onPressed = (){
                    device.disconnect();
                    Kbeacon.disconnect(device.id.toString()).then((value) => print(value));
                  };
                  text = 'DISCONNECT';
                  break;
                case BluetoothDeviceState.disconnected:
                  // onPressed = () => device.connect();
                  onPressed = (){
                    Kbeacon.connect(device.id.toString());
                  };
                  text = 'CONNECT';
                  break;
                default:
                  onPressed = null;
                  text = snapshot.data.toString().substring(21).toUpperCase();
                  break;
              }
              return ElevatedButton(
                  onPressed: onPressed,
                  child: Text(
                    text,
                    style: Theme.of(context)
                        .primaryTextTheme
                        .button
                        ?.copyWith(color: Colors.white),
                  ));
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            /// Device's state and name
            StreamBuilder<BluetoothDeviceState>(
              stream: device.state,
              initialData: BluetoothDeviceState.connecting,
              builder: (c, snapshot) => ListTile(
                leading: (snapshot.data == BluetoothDeviceState.connected)
                    ? Icon(Icons.bluetooth_connected)
                    : Icon(Icons.bluetooth_disabled),
                title: Text(
                    'Device is ${snapshot.data.toString().split('.')[1]}.'),
                subtitle: Text('${device.id}\n '),
                isThreeLine: true,
                trailing: StreamBuilder<bool>(
                  stream: device.isDiscoveringServices,
                  initialData: false,
                  builder: (c, snapshot) => IndexedStack(
                    index: snapshot.data! ? 1 : 0,
                    children: <Widget>[
                      IconButton(
                        icon: Icon(Icons.refresh),
                        onPressed: (){},
                        // onPressed: () => device.discoverServices(),
                      ),
                      IconButton(
                        icon: SizedBox(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation(Colors.grey),
                          ),
                          width: 18.0,
                          height: 18.0,
                        ),
                        onPressed: null,
                      )
                    ],
                  ),
                ),
              ),
            ),
            /// Device's maximum transimission unit
            StreamBuilder<int>(
              stream: device.mtu,
              initialData: 0,
              builder: (c, snapshot) => ListTile(
                title: Text('MTU Size'),
                subtitle: Text('${snapshot.data} bytes'),
                trailing: IconButton(
                  icon: Icon(Icons.edit),
                  onPressed: () {
                    device.requestMtu(246);
                  },
                ),
              ),
            ),
            // StreamBuilder<List<BluetoothService>>(
            //   stream: device.services,
            //   initialData: [],
            //   builder: (c, snapshot) {
            //     print(snapshot.data.toString() + " device.services");
            //     return Column(
            //       children: _buildServiceTiles(snapshot.data),
            //     );
            //     // return Container();
            //   },
            // ),
          ],
        ),
      ),
    );
  }
}