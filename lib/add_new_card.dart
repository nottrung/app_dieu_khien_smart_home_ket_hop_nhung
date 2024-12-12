import 'package:flutter/material.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:firebase_database/firebase_database.dart';

class AddNewCardPage extends StatefulWidget {
  @override
  _AddNewCardPageState createState() => _AddNewCardPageState();
}

class _AddNewCardPageState extends State<AddNewCardPage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  String _cardUID = '';
  String _statusMessage = '';

  // Hàm để đọc UID từ thẻ NFC
  Future<void> _readNFC() async {
    setState(() {
      _statusMessage = 'Waiting for NFC card...';
    });

    try {
      NFCTag tag = await FlutterNfcKit.poll(timeout: Duration(seconds: 10));
      setState(() {
        _cardUID = tag.id ?? 'Unknown UID';
        _statusMessage = 'Card UID: $_cardUID';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to read NFC: $e';
      });
    }
  }

  // Hàm để thêm UID vào Firebase
  Future<void> _addCardToFirebase() async {
    if (_cardUID.isEmpty) {
      setState(() {
        _statusMessage = 'No UID to add.';
      });
      return;
    }

    try {
      // Lấy danh sách các UID từ Firebase
      final snapshot = await _dbRef.child('door/cards').get();
      List<dynamic> existingUIDs = [];

      if (snapshot.exists) {
        existingUIDs = List<dynamic>.from(snapshot.value as List<dynamic>);
      }

      // Kiểm tra xem UID đã tồn tại hay chưa
      if (existingUIDs.contains(_cardUID)) {
        setState(() {
          _statusMessage = 'UID already exists!';
        });
        return;
      }

      // Thêm UID mới vào danh sách UID trong Firebase
      existingUIDs.add(_cardUID);
      await _dbRef.child('door/cards').set(existingUIDs);

      setState(() {
        _statusMessage = 'Card added successfully!';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to add card: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add New Card')),
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
                onPressed: _readNFC,
                child: const Text('Scan NFC Card'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _addCardToFirebase,
                child: const Text('Add Card to Firebase'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
