import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:http/http.dart' as http;
import 'device_screen.dart';
import '../utils/snackbar.dart';
import '../widgets/system_device_tile.dart';
import '../widgets/scan_result_tile.dart';
import '../utils/extra.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({Key? key}) : super(key: key);

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  List<BluetoothDevice> _systemDevices = [];
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  late StreamSubscription<List<ScanResult>> _scanResultsSubscription;
  late StreamSubscription<bool> _isScanningSubscription;

  @override
  void initState() {
    super.initState();

    _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
      _scanResults = results;
      if (mounted) {
        setState(() {});
      }
    }, onError: (e) {
      Snackbar.show(ABC.b, prettyException("Scan Error:", e), success: false);
    });

    _isScanningSubscription = FlutterBluePlus.isScanning.listen((state) {
      _isScanning = state;
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _scanResultsSubscription.cancel();
    _isScanningSubscription.cancel();
    super.dispose();
  }

  Future onScanPressed() async {
    try {
      _systemDevices = await FlutterBluePlus.systemDevices;
    } catch (e) {
      Snackbar.show(ABC.b, prettyException("System Devices Error:", e),
          success: false);
    }
    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
    } catch (e) {
      Snackbar.show(ABC.b, prettyException("Start Scan Error:", e),
          success: false);
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future onSubmitPressed() async {
    await Firebase.initializeApp();

    var allDevices = [
      ..._systemDevices.map((e) => e.platformName).toList(),
      ..._scanResults.map((e) => e.device.platformName)
    ].where((device) => device.isNotEmpty).toSet().toList();

    Snackbar.show(
        ABC.b,
        prettyException(
            allDevices.join(","), "Are the devices Present around you"),
        success: false);

    final devices = <String, dynamic>{"devices": allDevices};

    DocumentReference docRef = FirebaseFirestore.instance
        .collection('devices')
        .doc('kUthuGQJTt1c5wsRov1l');

    await docRef.update(devices);

    Snackbar.show(
        ABC.b,
        prettyException(
            allDevices.join(","), "Completed Storing these Devices"),
        success: false);

    await getSalesRepName();
  }

  Future onStopPressed() async {
    try {
      FlutterBluePlus.stopScan();
    } catch (e) {
      Snackbar.show(ABC.b, prettyException("Stop Scan Error:", e),
          success: false);
    }
  }

  void onConnectPressed(BluetoothDevice device) {
    device.connectAndUpdateStream().catchError((e) {
      Snackbar.show(ABC.c, prettyException("Connect Error:", e),
          success: false);
    });
    MaterialPageRoute route = MaterialPageRoute(
        builder: (context) => DeviceScreen(device: device),
        settings: RouteSettings(name: '/DeviceScreen'));
    Navigator.of(context).push(route);
  }

  Future onRefresh() {
    if (_isScanning == false) {
      FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
    }
    if (mounted) {
      setState(() {});
    }
    return Future.delayed(Duration(milliseconds: 500));
  }

  Widget buildScanButton(BuildContext context) {
    if (FlutterBluePlus.isScanningNow) {
      return FloatingActionButton(
        child: const Icon(Icons.stop),
        onPressed: onStopPressed,
        backgroundColor: Colors.red,
      );
    } else {
      return FloatingActionButton(
          child: const Text("SCAN"), onPressed: onScanPressed);
    }
  }

  Widget buildSubmitButton(BuildContext context) {
    if (FlutterBluePlus.isScanningNow) {
      return FloatingActionButton(
        child: const Icon(Icons.stop),
        onPressed: onStopPressed,
        backgroundColor: Colors.red,
      );
    } else {
      return FloatingActionButton(
          child: const Text("SUBMIT"), onPressed: onSubmitPressed);
    }
  }

  List<Widget> _buildSystemDeviceTiles(BuildContext context) {
    return _systemDevices
        .where((element) => element.platformName.isNotEmpty)
        .map(
          (d) => SystemDeviceTile(
            device: d,
            onOpen: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => DeviceScreen(device: d),
                settings: RouteSettings(name: '/DeviceScreen'),
              ),
            ),
            onConnect: () => onConnectPressed(d),
          ),
        )
        .toList();
  }

  Future<String> getSalesRepName() async {
    Snackbar.show(
        ABC.b, prettyException("Fetching bearer token ", ""),
        success: false);
    Token token = await getBearerToken();
    Snackbar.show(
        ABC.b, prettyException("Fetched bearer token successfully ", ""),
        success: false);
    print(token);
    final response = await http.get(
      Uri.parse(
          'https://dev1.wcms.mycase.medtronic.com/occ/v2/mdt_b2bsite_us/vendorApi/getSalesRep/0001109789'),
      headers: <String, String>{
        HttpHeaders.authorizationHeader: 'Bearer ' + token.access_token,
        'vendorId': 'UH',
        'version': '2',
      },
    );

    Snackbar.show(
        ABC.b, prettyException("The response is ", jsonEncode(response)),
        success: false);

    return "Hello";
  }

  Future<Token> getBearerToken() async {
    print('getting bearertoken');
    try {
      http.Response bearerResponse = await http.post(
        Uri.parse(
            'https://dev1.wcms.mycase.medtronic.com/authorizationserver/oauth/token?client_id=MULESOFT_NON_PROD&client_secret=gS8ms63ks7ALWS1&grant_type=client_credentials&scope=extended'),
      );
      print('checking bearerResponse');
      if (bearerResponse.statusCode == 200) {
        return Token.fromJson(bearerResponse.body as Map<String, dynamic>);
      } else {
        // If the server did not return a 201 CREATED response,
        // then throw an exception.
        throw Exception('Failed to create Token.');
      }
    } catch (e) {
      print('In exception');
      print(e);
      throw Exception('Failed to create Token.');
    }
  }

  List<Widget> _buildScanResultTiles(BuildContext context) {
    return _scanResults
        .where((element) => element.device.platformName.isNotEmpty)
        .map(
          (r) => ScanResultTile(
            result: r,
            onTap: () => onConnectPressed(r.device),
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: Snackbar.snackBarKeyB,
      child: Scaffold(
          appBar: AppBar(
            title: const Text('Find Devices'),
          ),
          body: RefreshIndicator(
            onRefresh: onRefresh,
            child: ListView(
              children: <Widget>[
                ..._buildSystemDeviceTiles(context),
                ..._buildScanResultTiles(context),
              ],
            ),
          ),
          floatingActionButton: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [buildScanButton(context), buildSubmitButton(context)],
          )),
    );
  }
}

class Token {
  final String access_token;
  final String token_type;
  final int expires_in;
  final String scope;

  const Token({
    required this.access_token,
    required this.token_type,
    required this.expires_in,
    required this.scope,
  });

  factory Token.fromJson(Map<String, dynamic> json) {
    switch (json.keys.toSet()) {
      case {
        'access_token',
        'token_type',
        'expires_in',
        'scope',
      }:
        return Token(
          access_token: json['access_token'] as String,
          token_type: json['token_type'] as String,
          expires_in: json['expires_in'] as int,
          scope: json['scope'] as String,
        );
      default:
        throw FormatException('Failed to parse token');
    }
  }
}
