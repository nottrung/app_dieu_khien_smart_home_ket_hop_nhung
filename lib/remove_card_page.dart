import 'package:flutter/material.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:firebase_database/firebase_database.dart';

class RemoveCardPage extends StatefulWidget {
  @override
  _RemoveCardPageState createState() => _RemoveCardPageState();
}

class _RemoveCardPageState extends State<RemoveCardPage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  String _cardUID = '';
  String _statusMessage = '';
  List<String> _cardUIDs = [];

  @override
  void initState() {
    super.initState();
    _fetchCardUIDs(); // Lấy danh sách UID từ Firebase khi khởi tạo
  }

  // Hàm để lấy danh sách UID từ Firebase
  Future<void> _fetchCardUIDs() async {
    try {
      final snapshot = await _dbRef.child('door/cards').get();
      if (snapshot.exists && snapshot.value is List) {
        setState(() {
          _cardUIDs = List<String>.from(snapshot.value as List);
        });
      } else {
        setState(() {
          _cardUIDs = [];
          _statusMessage = 'No cards found in database.';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error fetching card UIDs: $e';
      });
    }
  }

  // Hàm để quét thẻ NFC và lấy UID
  Future<void> _scanNFC() async {
    setState(() {
      _statusMessage = 'Waiting for NFC card...';
    });

    try {
      NFCTag tag = await FlutterNfcKit.poll(timeout: Duration(seconds: 10));
      setState(() {
        _cardUID = tag.id ?? 'Unknown UID';
        _statusMessage = 'Scanned UID: $_cardUID';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to read NFC: $e';
      });
    }
  }

  // Hàm để xóa UID khỏi Firebase
  Future<void> _removeCardFromFirebase() async {
    if (_cardUID.isEmpty) {
      setState(() {
        _statusMessage = 'No UID scanned.';
      });
      return;
    }

    try {
      if (_cardUIDs.contains(_cardUID)) {
        _cardUIDs.remove(_cardUID); // Xóa UID khỏi danh sách

        // Cập nhật lại danh sách UID trong Firebase
        await _dbRef.child('door/cards').set(_cardUIDs);

        setState(() {
          _statusMessage = 'Card removed successfully!';
        });
      } else {
        setState(() {
          _statusMessage = 'UID not found in database.';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to remove card: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Remove Card')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _statusMessage,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _scanNFC,
                child: const Text('Scan NFC Card'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _removeCardFromFirebase,
                child: const Text('Remove Card'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
