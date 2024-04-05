import 'dart:io';

import 'package:bootloader_host/cybtldr_api.dart';
import 'package:bootloader_host/cybtldr_api2.dart';
import 'package:bootloader_host/cybtldr_ble_comms.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:path/path.dart' as path;

import 'package:go_router/go_router.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  if (Platform.isAndroid) {
    WidgetsFlutterBinding.ensureInitialized();
    [
      Permission.location,
      Permission.storage,
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan
    ].request().then((status) {
      runApp(const MyApp());
    });
  } else {
    runApp(const MyApp());
  }
}

final _router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const MyHomePage(),
    ),
    //GoRoute(path: '/')
  ],
);

final snackBarKeyC = GlobalKey<ScaffoldMessengerState>();

final Map<DeviceIdentifier, ValueNotifier<bool>> isConnectingOrDisconnecting =
    {};

final Map<BluetoothConnectionState, ValueNotifier<bool>> isConnected = {};

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color.fromRGBO(0, 142, 193, 1)),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            brightness: Brightness.dark,
            seedColor: const Color.fromRGBO(0, 142, 193, 1)),
      ),
      themeMode: ThemeMode.dark,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}

class MyHomePage extends StatelessWidget {
  //const MyHomePage({super.key, required this.title});
  const MyHomePage({super.key});

  //final String title;

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
    return Scaffold(
      /*appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),*/
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Spacer(),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () {},
              label: const Text("Engineer Login"),
              icon: const Icon(Icons.admin_panel_settings),
            ),
            const SizedBox(
              height: 20,
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const FridgeConnectPage()));
              },
              label: const Text("Fridge Connect"),
              icon: const Icon(Icons.bluetooth_searching),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class FridgeConnectPage extends StatefulWidget {
  const FridgeConnectPage({super.key});

  @override
  State<FridgeConnectPage> createState() => _FridgeConnectPageState();
}

class _FridgeConnectPageState extends State<FridgeConnectPage> {
  Future<bool> bleAvailable() async {
    if (await FlutterBluePlus.isAvailable) {
      if (FlutterBluePlus.isScanningNow == false) {
        try {
          FlutterBluePlus.startScan(
              timeout: const Duration(seconds: 15),
              androidUsesFineLocation: false);
        } catch (e) {
          return false;
        }
      }
      return true;
    } else {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.

    return FutureBuilder<bool>(
        future: bleAvailable(),
        builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          } else if (!(snapshot.data ?? false)) {
            context.pop();
            return const Center(
              child: CircularProgressIndicator(),
            );
          } else {
            return Scaffold(
              appBar: AppBar(
                // TRY THIS: Try changing the color here to a specific color (to
                // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
                // change color while the other colors stay the same.
                backgroundColor: Theme.of(context).colorScheme.inversePrimary,
                // Here we take the value from the MyHomePage object that was created by
                // the App.build method, and use it to set our appbar title.
                title: const Text("Available Connections"),
                actions: <Widget>[
                  IconButton(
                      onPressed: () {
                        if (FlutterBluePlus.isScanningNow == false) {
                          FlutterBluePlus.startScan(
                              timeout: const Duration(seconds: 15),
                              androidUsesFineLocation: false);
                        }
                      },
                      icon: const Icon(Icons.loop))
                ],
              ),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    RefreshIndicator(
                      onRefresh: () {
                        setState(
                            () {}); // force refresh of connectedSystemDevices
                        if (FlutterBluePlus.isScanningNow == false) {
                          FlutterBluePlus.startScan(
                              timeout: const Duration(seconds: 15),
                              androidUsesFineLocation: false);
                        }
                        return Future.delayed(const Duration(
                            milliseconds: 500)); // show refresh icon breifly
                      },
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            StreamBuilder<List<BluetoothDevice>>(
                              stream: Stream.fromFuture(
                                  FlutterBluePlus.connectedSystemDevices),
                              initialData: const [],
                              builder: (c, snapshot) => Column(
                                children: (snapshot.data ?? [])
                                    .map((d) => ListTile(
                                          title: Text(d.localName),
                                          //subtitle: Text(d.remoteId.toString()),
                                          trailing: StreamBuilder<
                                              BluetoothConnectionState>(
                                            stream: d.connectionState,
                                            initialData:
                                                BluetoothConnectionState
                                                    .disconnected,
                                            builder: (c, snapshot) {
                                              if (snapshot.data ==
                                                  BluetoothConnectionState
                                                      .connected) {}
                                              if (snapshot.data ==
                                                  BluetoothConnectionState
                                                      .disconnected) {
                                                return ElevatedButton(
                                                    child:
                                                        const Text('CONNECT'),
                                                    onPressed: () {
                                                      Navigator.of(context).push(
                                                          MaterialPageRoute(
                                                              builder:
                                                                  (context) {
                                                                isConnectingOrDisconnecting[
                                                                        d.remoteId] ??=
                                                                    ValueNotifier(
                                                                        true);
                                                                isConnectingOrDisconnecting[
                                                                        d.remoteId]!
                                                                    .value = true;
                                                                d
                                                                    .connect(
                                                                        timeout: const Duration(
                                                                            seconds:
                                                                                35))
                                                                    .catchError(
                                                                        (e) {
                                                                  final snackBar =
                                                                      snackBarFail(prettyException(
                                                                          "Connect Error:",
                                                                          e));
                                                                  snackBarKeyC
                                                                      .currentState
                                                                      ?.removeCurrentSnackBar();
                                                                  snackBarKeyC
                                                                      .currentState
                                                                      ?.showSnackBar(
                                                                          snackBar);
                                                                }).then((v) {
                                                                  isConnectingOrDisconnecting[
                                                                          d.remoteId] ??=
                                                                      ValueNotifier(
                                                                          false);
                                                                  isConnectingOrDisconnecting[
                                                                          d.remoteId]!
                                                                      .value = false;
                                                                });
                                                                d.createBond();
                                                                return DeviceScreen(
                                                                    device: d);
                                                              },
                                                              settings:
                                                                  const RouteSettings(
                                                                      name:
                                                                          '/deviceScreen')));
                                                    });
                                              }
                                              return Text(snapshot.data
                                                  .toString()
                                                  .toUpperCase()
                                                  .split('.')[1]);
                                            },
                                          ),
                                        ))
                                    .toList(),
                              ),
                            ),
                            StreamBuilder<List<ScanResult>>(
                              stream: FlutterBluePlus.scanResults,
                              initialData: const [],
                              builder: (c, snapshot) => Column(
                                children: (snapshot.data ?? [])
                                    .where((element) =>
                                        element.device.localName.isNotEmpty)
                                    .map(
                                      (r) => ScanResultTile(
                                        result: r,
                                        onTap: () => Navigator.of(context).push(
                                            MaterialPageRoute(
                                                builder: (context) {
                                                  isConnectingOrDisconnecting[
                                                          r.device.remoteId] ??=
                                                      ValueNotifier(true);
                                                  isConnectingOrDisconnecting[
                                                          r.device.remoteId]!
                                                      .value = true;
                                                  r.device
                                                      .connect(
                                                          timeout:
                                                              const Duration(
                                                                  seconds: 35))
                                                      .catchError((e) {
                                                    final snackBar =
                                                        snackBarFail(
                                                            prettyException(
                                                                "Connect Error:",
                                                                e));
                                                    snackBarKeyC.currentState
                                                        ?.removeCurrentSnackBar();
                                                    snackBarKeyC.currentState
                                                        ?.showSnackBar(
                                                            snackBar);
                                                  }).then((v) {
                                                    isConnectingOrDisconnecting[
                                                            r.device
                                                                .remoteId] ??=
                                                        ValueNotifier(false);
                                                    isConnectingOrDisconnecting[
                                                            r.device.remoteId]!
                                                        .value = false;
                                                  });
                                                  //g_comm.OpenConnection();
                                                  return DeviceScreen(
                                                      device: r.device);
                                                },
                                                settings: const RouteSettings(
                                                    name: '/deviceScreen'))),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        });
  }
}

class DeviceScreen extends StatelessWidget {
  final BluetoothDevice device;
  const DeviceScreen({Key? key, required this.device}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
        child: Scaffold(
      appBar: AppBar(
        title: const Text("Firmware Update"),
        actions: <Widget>[
          StreamBuilder<BluetoothConnectionState>(
            stream: device.connectionState,
            initialData: BluetoothConnectionState.connecting,
            builder: (c, snapshot) {
              VoidCallback? onPressed;
              String text;
              switch (snapshot.data) {
                case BluetoothConnectionState.connected:
                  onPressed = () async {
                    isConnectingOrDisconnecting[device.remoteId] ??=
                        ValueNotifier(true);
                    isConnectingOrDisconnecting[device.remoteId]!.value = true;
                    try {
                      await device.disconnect();
                      final snackBar = snackBarGood("Disconnect: Success");
                      snackBarKeyC.currentState?.removeCurrentSnackBar();
                      snackBarKeyC.currentState?.showSnackBar(snackBar);
                    } catch (e) {
                      final snackBar =
                          snackBarFail(prettyException("Disconnect Error:", e));
                      snackBarKeyC.currentState?.removeCurrentSnackBar();
                      snackBarKeyC.currentState?.showSnackBar(snackBar);
                    }
                    isConnectingOrDisconnecting[device.remoteId] ??=
                        ValueNotifier(false);
                    isConnectingOrDisconnecting[device.remoteId]!.value = false;
                  };
                  text = 'DISCONNECT';
                  break;
                case BluetoothConnectionState.disconnected:
                  onPressed = () async {
                    isConnectingOrDisconnecting[device.remoteId] ??=
                        ValueNotifier(true);
                    isConnectingOrDisconnecting[device.remoteId]!.value = true;
                    try {
                      await device.connect(
                          timeout: const Duration(seconds: 35));
                      g_comm.SetDevice(device);
                      final snackBar = snackBarGood("Connect: Success");
                      snackBarKeyC.currentState?.removeCurrentSnackBar();
                      snackBarKeyC.currentState?.showSnackBar(snackBar);
                    } catch (e) {
                      final snackBar =
                          snackBarFail(prettyException("Connect Error:", e));
                      snackBarKeyC.currentState?.removeCurrentSnackBar();
                      snackBarKeyC.currentState?.showSnackBar(snackBar);
                    }
                    isConnectingOrDisconnecting[device.remoteId] ??=
                        ValueNotifier(false);
                    isConnectingOrDisconnecting[device.remoteId]!.value = false;
                  };
                  text = 'CONNECT';
                  break;
                default:
                  onPressed = null;
                  text = snapshot.data.toString().split(".").last.toUpperCase();
                  break;
              }
              return ValueListenableBuilder<bool>(
                  valueListenable:
                      isConnectingOrDisconnecting[device.remoteId]!,
                  builder: (context, value, child) {
                    isConnectingOrDisconnecting[device.remoteId] ??=
                        ValueNotifier(false);
                    if (isConnectingOrDisconnecting[device.remoteId]!.value ==
                        true) {
                      // Show spinner when connecting or disconnecting
                      return const Padding(
                        padding: EdgeInsets.all(14.0),
                        child: AspectRatio(
                          aspectRatio: 1.0,
                          child: CircularProgressIndicator(
                            backgroundColor: Colors.black12,
                            color: Colors.black26,
                          ),
                        ),
                      );
                    } else {
                      return TextButton(
                          onPressed: onPressed,
                          child: Text(
                            text,
                            style: Theme.of(context)
                                .primaryTextTheme
                                .labelLarge
                                ?.copyWith(color: Colors.white),
                          ));
                    }
                  });
            },
          ),
        ],
      ),
      body: FloatingActionButton(
        child: const Text("Start Update"),
        onPressed: () async {
          try {
            FilePickerResult? result =
                await FilePicker.platform.pickFiles(type: FileType.any);
            if (result != null) {
              String pathToFile = result.files.single.path ?? "";
              if (pathToFile != "") {
                File file = File(pathToFile);
                final extension = path.extension(pathToFile);
                if (extension == ".cyacd" || extension == ".cyacd2") {
                  int t = await CyBtldr_Program(file, "", 3, device);
                  final snackBar = snackBarGood(t.toString());
                  snackBarKeyC.currentState?.removeCurrentSnackBar();
                  snackBarKeyC.currentState?.showSnackBar(snackBar);
                }
              }
            }
/*             CyBtldr_CommunicationsData data = CyBtldr_CommunicationsData();
            data.SetDevice(device);
            await data.OpenConnection();
            data.WriteData(Uint8List.fromList([54, 45, 53, 54]), 4); */
          } catch (e) {
            final snackBar = snackBarFail(e.toString());
            snackBarKeyC.currentState?.removeCurrentSnackBar();
            snackBarKeyC.currentState?.showSnackBar(snackBar);
          }
        },
      ),
    ));
  }
}

class ScanResultTile extends StatelessWidget {
  const ScanResultTile({Key? key, required this.result, this.onTap})
      : super(key: key);

  final ScanResult result;
  final VoidCallback? onTap;

  Widget _buildTitle(BuildContext context) {
    if (result.device.localName.isNotEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            result.device.localName,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    } else {
      return Text(result.device.remoteId.toString());
    }
  }

  Widget _buildAdvRow(BuildContext context, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(
            width: 12.0,
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.apply(color: Colors.black),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  String getNiceHexArray(List<int> bytes) {
    return '[${bytes.map((i) => i.toRadixString(16).padLeft(2, '0')).join(', ')}]'
        .toUpperCase();
  }

  String getNiceManufacturerData(Map<int, List<int>> data) {
    if (data.isEmpty) {
      return 'N/A';
    }
    List<String> res = [];
    data.forEach((id, bytes) {
      res.add(
          '${id.toRadixString(16).toUpperCase()}: ${getNiceHexArray(bytes)}');
    });
    return res.join(', ');
  }

  String getNiceServiceData(Map<String, List<int>> data) {
    if (data.isEmpty) {
      return 'N/A';
    }
    List<String> res = [];
    data.forEach((id, bytes) {
      res.add('${id.toUpperCase()}: ${getNiceHexArray(bytes)}');
    });
    return res.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: _buildTitle(context),

      //leading: Text(""),
      trailing: ElevatedButton(
        onPressed: (result.advertisementData.connectable) ? onTap : null,
        child: const Text('CONNECT'),
      ),
      children: <Widget>[
        _buildAdvRow(
            context, 'Complete Local Name', result.advertisementData.localName),
        _buildAdvRow(context, 'Tx Power Level',
            '${result.advertisementData.txPowerLevel ?? 'N/A'}'),
        _buildAdvRow(context, 'Manufacturer Data',
            getNiceManufacturerData(result.advertisementData.manufacturerData)),
        _buildAdvRow(
            context,
            'Service UUIDs',
            (result.advertisementData.serviceUuids.isNotEmpty)
                ? result.advertisementData.serviceUuids.join(', ').toUpperCase()
                : 'N/A'),
        _buildAdvRow(context, 'Service Data',
            getNiceServiceData(result.advertisementData.serviceData)),
      ],
    );
  }
}

String prettyException(String prefix, dynamic e) {
  if (e is FlutterBluePlusException) {
    return "$prefix ${e.description}";
  } else if (e is PlatformException) {
    return "$prefix ${e.message}";
  }
  return prefix + e.toString();
}

SnackBar snackBarFail(String message) {
  return SnackBar(content: Text(message), backgroundColor: Colors.red);
}

SnackBar snackBarGood(String message) {
  return SnackBar(content: Text(message), backgroundColor: Colors.blue);
}
