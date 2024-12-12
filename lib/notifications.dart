import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class Notifications extends StatefulWidget {
  const Notifications({super.key});

  @override
  _NotificationsState createState() => _NotificationsState();
}

class _NotificationsState extends State<Notifications> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    _dbRef.child('notifications').onValue.listen((event) {
      final notifications = event.snapshot.value as Map<dynamic, dynamic>?;
      if (notifications != null) {
        setState(() {
          _notifications = notifications.entries.map((entry) {
            return {
              'key': entry.key,
              'title': entry.value['title'],
              'body': entry.value['body'],
              'timestamp': entry.value['timestamp'],
            };
          }).toList();

          // Sort notifications by timestamp in descending order
          _notifications.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
        });
      }
    });
  }

  String _formatTimestamp(int timestamp) {
    // Convert timestamp to DateTime
    DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    // Format as a readable string
    return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: _notifications.isNotEmpty
          ? ListView.builder(
        itemCount: _notifications.length,
        itemBuilder: (context, index) {
          final notification = _notifications[index];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification['title'] ?? 'No Title',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    notification['body'] ?? 'No Body',
                    style: const TextStyle(
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _formatTimestamp(notification['timestamp']),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      )
          : const Center(
        child: Text(
          'No notifications to display',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
