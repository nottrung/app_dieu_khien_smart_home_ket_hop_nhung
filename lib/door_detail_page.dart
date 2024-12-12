import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'add_new_card.dart';
import 'remove_card_page.dart';

class DoorDetailPage extends StatefulWidget {
  final bool isOn;
  final Function(bool) onToggle;

  const DoorDetailPage({super.key, required this.isOn, required this.onToggle});

  @override
  _DoorDetailPageState createState() => _DoorDetailPageState();
}

class _DoorDetailPageState extends State<DoorDetailPage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  bool _isOpen = false;
  List<String> _cardUIDs = [];
  String _oldPassword = '';
  String _newPassword = '';
  String _errorMessage = '';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _isOpen = widget.isOn;
    _startFetchingData();
    _fetchCardUIDs();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startFetchingData() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final snapshot = await _dbRef.child('door/status').get();
      if (snapshot.exists && snapshot.value == true) {
        setState(() {
          _isOpen = true;
        });
      } else {
        setState(() {
          _isOpen = false;
        });
      }
    });
  }

  Future<void> _fetchCardUIDs() async {
    try {
      final snapshot = await _dbRef.child('door/cards').get();
      if (snapshot.exists) {
        if (snapshot.value is List) {
          setState(() {
            _cardUIDs = List<String>.from(snapshot.value as List);
          });
        } else if (snapshot.value is Map) {
          final Map<dynamic, dynamic> cardsMap =
          snapshot.value as Map<dynamic, dynamic>;
          setState(() {
            _cardUIDs =
                cardsMap.values.map((uid) => uid.toString()).toList();
          });
        }
      } else {
        setState(() {
          _cardUIDs = [];
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching card UIDs: $e';
      });
    }
  }

  Future<void> _sendNotification(String title, String body) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    await _dbRef.child('notifications').push().set({
      'title': title,
      'body': body,
      'timestamp': timestamp,
    });
  }

  Future<void> _updatePassword() async {
    final passwordSnapshot = await _dbRef.child('door/password').get();
    if (_oldPassword != passwordSnapshot.value) {
      setState(() {
        _errorMessage = 'Incorrect old password';
      });
    } else if (_oldPassword == _newPassword) {
      setState(() {
        _errorMessage = 'New password cannot be the same as old password';
      });
    } else {
      await _dbRef.child('door/password').set(_newPassword);
      await _sendNotification(
        'Password Updated',
        'The door password was successfully updated.',
      );
      setState(() {
        _errorMessage = 'Password updated successfully';
      });
    }
  }

  void _toggleDoorStatus() {
    setState(() {
      _isOpen = !_isOpen;
      widget.onToggle(_isOpen);
      _dbRef.child('door/status').set(_isOpen);
    });
    _sendNotification(
      'Door ${_isOpen ? 'Opened' : 'Closed'}',
      'The door was ${_isOpen ? 'opened' : 'closed'}.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Door Details"),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.door_back_door,
                size: 120,
                color: _isOpen ? Colors.yellow : Colors.grey,
              ),
              const SizedBox(height: 10),
              Text(
                _isOpen ? 'Status: Open' : 'Status: Close',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _toggleDoorStatus,
                child: Text(
                  _isOpen ? 'Close Door' : 'Open Door',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              const SizedBox(height: 20),
              const Divider(),
              ElevatedButton(
                onPressed: _showPasswordChangeDialog,
                child: const Text('Change Password'),
              ),
              if (_errorMessage.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => AddNewCardPage()),
                        ).then((_) {
                          _fetchCardUIDs();
                          _sendNotification(
                            'Card Added',
                            'A new card was added to the system.',
                          );
                        });
                      },
                      child: const Text('Add New Card'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => RemoveCardPage()),
                        ).then((_) {
                          _fetchCardUIDs();
                          _sendNotification(
                            'Card Removed',
                            'A card was removed from the system.',
                          );
                        });
                      },
                      child: const Text('Remove A Card'),
                    ),
                  ],
                ),
              ),
              const Text(
                'Card UID List',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _cardUIDs.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      leading: const Icon(Icons.credit_card),
                      title: Text(_cardUIDs[index]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPasswordChangeDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Change Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'Old Password'),
                onChanged: (value) => _oldPassword = value,
                obscureText: true,
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'New Password'),
                onChanged: (value) => _newPassword = value,
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                _updatePassword();
                Navigator.of(context).pop();
              },
              child: const Text('Change'),
            ),
          ],
        );
      },
    );
  }
}
