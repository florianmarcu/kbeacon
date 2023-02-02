import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
// import 'package:flutter_ble_lib/flutter_ble_lib.dart' as ble;
import 'package:kbeacon/kbeacon.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:kbeacon_example/widgets.dart';
import 'package:workmanager/workmanager.dart';



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
  await Workmanager().initialize(
    callbackDispatcher, // The top level function, aka callbackDispatcher
    isInDebugMode: kDebugMode // If enabled it will post a notification whenever the task is running. Handy for debugging tasks
  );
  Workmanager().registerOneOffTask("task-identifier", "simpleTask",);


  // ble.BleManager bleManager = ble.BleManager();
  // await bleManager.createClient(); //ready to go! 

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
    FlutterBlue.instance.startScan();
    Kbeacon.buttonClickEvents.listen((event) {print("1");});
    initPlatformState();
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
                                          Kbeacon.enableButtonTrigger(d.id.toString());
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
                              onTap: (){
                                print(r.device.id);
                                Kbeacon.connect(r.device.id.toString());
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