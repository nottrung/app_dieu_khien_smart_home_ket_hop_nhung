import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:vibration/vibration.dart';
import 'device_detail.dart';
import 'door_detail_page.dart';
import 'fan_detail_page.dart';
import 'login_page.dart';
import 'multi_button.dart';
import 'notifications.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final List<String> _deviceNames = [
    'ligh1',
    'ligh2',
    'waterheater',
    'fan',
    'door',
    'gas'
  ];
  List<bool> _isOn = [false, false, false, false, false, false];
  bool _isWarning = false;
  bool _isGasWarningActive = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startFetchingData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    Vibration.cancel();
    super.dispose();
  }

  void _startFetchingData() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _fetchData();
    });
  }

  Future<void> _fetchData() async {
    try {
      List<bool> newStatusList = [];
      for (String device in _deviceNames) {
        final snapshot = await _dbRef.child('$device/status').get();
        newStatusList.add(snapshot.exists && snapshot.value == true);

        // Trigger vibration if the gas is turned on
        if (device == 'gas' && snapshot.exists && snapshot.value == true) {
          Vibration.vibrate();
        }
      }

      bool isDoorWarning = await _fetchDoorWarning();
      bool isGasWarning = await _fetchGasWarning();

      setState(() {
        _isOn = newStatusList;
        if (isDoorWarning && !_isWarning) {
          _showWarning();
          _sendNotification("Cảnh báo", "Có người lạ cố gắng mở cửa!", "door_warning");
        } else if (!isDoorWarning && _isWarning) {
          _hideWarning();
        }
        _isWarning = isDoorWarning;

        if (isGasWarning && !_isGasWarningActive) {
          _showGasWarning();
          _sendNotification("Cảnh báo", "Cảnh báo rò rỉ khí gas!", "gas_warning");
        } else if (!isGasWarning && _isGasWarningActive) {
          _hideGasWarning();
        }
        _isGasWarningActive = isGasWarning;
      });
    } catch (e) {
      print("Error fetching data: $e");
    }
  }

  Future<void> _sendNotification(String title, String body, String type) async {
    // Lưu thông báo vào Firebase Database
    await _dbRef.child('notifications').push().set({
      'title': title,
      'body': body,
      'type': type,
      'timestamp': ServerValue.timestamp,
    });

    // Gửi thông báo đến FCM (giả sử bạn đã cấu hình server FCM để gửi thông báo)
    // Bạn có thể sử dụng một dịch vụ cloud function hoặc API để gửi thông báo đến FCM
  }

  Future<bool> _fetchDoorWarning() async {
    try {
      final snapshot = await _dbRef.child('door/warning').get();
      return snapshot.exists && snapshot.value == true;
    } catch (e) {
      print("Error fetching door warning: $e");
      return false;
    }
  }

  Future<bool> _fetchGasWarning() async {
    try {
      final snapshot = await _dbRef.child('gas/status').get();
      return snapshot.exists && snapshot.value == true;
    } catch (e) {
      print("Error fetching gas warning: $e");
      return false;
    }
  }

  bool _isWarningActive = false;

  Future<void> _showWarning() async {
    setState(() {
      _isWarningActive = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 10),
            Text("Warning"),
          ],
        ),
        content: const Text("Có người lạ cố gắng mở cửa!"),
      ),
    );

    while (_isWarningActive) {
      Vibration.vibrate();
      await Future.delayed(Duration(milliseconds: 500));
    }
  }

  void _hideWarning() {
    setState(() {
      _isWarningActive = false;
    });

    Vibration.cancel();
    Navigator.of(context).pop();
  }

  Future<void> _showGasWarning() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 10),
            Text("Warning"),
          ],
        ),
        content: const Text("Cảnh báo rò rỉ khí gas!"),
      ),
    );

    while (_isGasWarningActive) {
      Vibration.vibrate();
      await Future.delayed(Duration(milliseconds: 500));
    }
  }

  void _hideGasWarning() {
    setState(() {
      _isGasWarningActive = false;
    });

    Vibration.cancel();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Home"),
        actions: [
          MultiFunctionButton(),
        ],
      ),
      endDrawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              child: Center(
                child: Text('Menu',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 54,
                        fontWeight: FontWeight.bold)),
              ),
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
            ),
            ListTile(
              leading: Icon(Icons.notifications),
              title: Text('Notifications'),
              onTap: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => Notifications()));
              },
            ),
            ListTile(
              leading: Icon(Icons.logout),
              title: Text('Log Out'),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => LoginPage()),
                      (Route<dynamic> route) => false,
                );
              },
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: _deviceNames.length,
          itemBuilder: (context, index) {
            return _buildDeviceBox(_deviceNames[index], index);
          },
        ),
      ),
    );
  }

  Widget _buildDeviceBox(String label, int index) {
    IconData iconData;
    Color iconColor = _isOn[index] ? Colors.yellow : Colors.grey;

    switch (label) {
      case 'ligh1':
      case 'ligh2':
        iconData = Icons.lightbulb;
        break;
      case 'waterheater':
        iconData = Icons.water_drop;
        break;
      case 'fan':
        iconData = Icons.air;
        break;
      case 'door':
        iconData = Icons.door_back_door;
        break;
      case 'gas':
        iconData = Icons.local_fire_department;
        iconColor = _isOn[index] ? Colors.red : Colors.grey;
        break;
      default:
        iconData = Icons.device_unknown;
        break;
    }

    // Nếu là gas, không cho phép nhấn, chỉ hiển thị
    if (label == 'gas') {
      return Container(
        decoration: BoxDecoration(
          color: Colors.blue[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              iconData,
              size: 50,
              color: iconColor,
            ),
            const SizedBox(height: 8),
            Text(
              label.replaceFirst('ligh', 'Light ').replaceFirst('door', 'Door'),
              style: TextStyle(
                fontSize: 16,
                color: _isOn[index] ? Colors.blue[900] : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    } else {
      return GestureDetector(
        onTap: () => label == 'door'
            ? _navigateToDoorDetail(index)
            : label == 'fan'
            ? _navigateToFanDetail(index)
            : _navigateToDeviceDetail(iconData, label, index),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blue[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                iconData,
                size: 50,
                color: iconColor,
              ),
              const SizedBox(height: 8),
              Text(
                label.replaceFirst('ligh', 'Light ').replaceFirst('door', 'Door'),
                style: TextStyle(
                  fontSize: 16,
                  color: _isOn[index] ? Colors.blue[900] : Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _navigateToDeviceDetail(IconData iconData, String label, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DeviceDetailPage(
          iconData: iconData,
          label: label,
          isOn: _isOn[index],
          onToggle: (value) {
            setState(() {
              _isOn[index] = value;
              _dbRef.child('${_deviceNames[index]}/status').set(value);
            });
          },
        ),
      ),
    );
  }

  void _navigateToDoorDetail(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DoorDetailPage(
          isOn: _isOn[index],
          onToggle: (value) {
            setState(() {
              _isOn[index] = value;
              _dbRef.child('door/status').set(value);
            });
          },
        ),
      ),
    );
  }

  void _navigateToFanDetail(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FanDetailPage(
          isOn: _isOn[index],
          onToggle: (value) {
            setState(() {
              _isOn[index] = value;
              _dbRef.child('fan/status').set(value);
            });
          },
        ),
      ),
    );
  }
}