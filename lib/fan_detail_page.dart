import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class FanDetailPage extends StatefulWidget {
  final bool isOn;
  final Function(bool) onToggle;

  const FanDetailPage({super.key, required this.isOn, required this.onToggle});

  @override
  _FanDetailPageState createState() => _FanDetailPageState();
}

class _FanDetailPageState extends State<FanDetailPage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  bool _isFanOn = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _isFanOn = widget.isOn;
    _startFetchingData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startFetchingData() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _fetchFanStatus();
    });
  }

  Future<void> _fetchFanStatus() async {
    try {
      final snapshot = await _dbRef.child('fan/status').get();
      if (snapshot.exists) {
        setState(() {
          _isFanOn = snapshot.value == true;
        });
      }
    } catch (e) {
      print("Error fetching fan status: $e");
    }
  }

  void _logFanStatusChange(bool isOn) async {
    try {
      String title = isOn ? 'Fan Turned ON' : 'Fan Turned OFF';
      String body = isOn ? 'The fan has been switched ON.' : 'The fan has been switched OFF.';
      int timestamp = DateTime.now().millisecondsSinceEpoch;

      await _dbRef.child('notifications').push().set({
        'title': title,
        'body': body,
        'timestamp': timestamp,
      });
    } catch (e) {
      print('Error logging notification: $e');
    }
  }

  void _toggleFanStatus() {
    setState(() {
      _isFanOn = !_isFanOn;
      widget.onToggle(_isFanOn);
      _dbRef.child('fan/status').set(_isFanOn);
      _logFanStatusChange(_isFanOn); // Log the fan status change
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Fan Details"),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.air,
                size: 120,
                color: _isFanOn ? Colors.yellow : Colors.grey,
              ),
              const SizedBox(height: 10),
              Text(
                _isFanOn ? 'Status : ON' : 'Status : OFF',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _toggleFanStatus,
                child: Text(
                  _isFanOn ? 'Turn OFF' : 'Turn ON',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
