import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class DeviceDetailPage extends StatefulWidget {
  final IconData iconData;
  final String label;
  final bool isOn;
  final ValueChanged<bool> onToggle;

  const DeviceDetailPage({
    Key? key,
    required this.iconData,
    required this.label,
    required this.isOn,
    required this.onToggle,
  }) : super(key: key);

  @override
  State<DeviceDetailPage> createState() => _DeviceDetailPageState();
}

class _DeviceDetailPageState extends State<DeviceDetailPage> {
  late bool isOn;
  bool isAuto = false;
  TimeOfDay? onTime;
  TimeOfDay? offTime;
  Timer? _timer; // Thêm timer

  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  @override
  void initState() {
    super.initState();
    isOn = widget.isOn;
    _fetchDeviceSettings(); // Lấy dữ liệu từ Firebase khi khởi chạy
    _startAutoReload(); // Bắt đầu tự động tải lại
  }

  @override
  void dispose() {
    _timer?.cancel(); // Hủy timer khi trang bị hủy
    super.dispose();
  }

  // Bắt đầu tự động tải lại sau mỗi giây
  void _startAutoReload() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _fetchDeviceSettings();
    });
  }

  // Hàm để lấy dữ liệu từ Firebase
  Future<void> _fetchDeviceSettings() async {
    final String deviceKey = widget.label.toLowerCase().replaceAll(' ', '');

    try {
      // Lấy trạng thái của auto
      final autoSnapshot = await _dbRef.child('$deviceKey/auto').get();
      if (autoSnapshot.exists) {
        setState(() {
          isAuto = autoSnapshot.value as bool;
        });
      }

      // Lấy thời gian ontime
      final onTimeSnapshot = await _dbRef.child('$deviceKey/ontime').get();
      if (onTimeSnapshot.exists && onTimeSnapshot.value != "00:00") {
        final parts = (onTimeSnapshot.value as String).split(":");
        setState(() {
          onTime = TimeOfDay(
            hour: int.parse(parts[0]),
            minute: int.parse(parts[1]),
          );
        });
      }

      // Lấy thời gian offtime
      final offTimeSnapshot = await _dbRef.child('$deviceKey/offtime').get();
      if (offTimeSnapshot.exists && offTimeSnapshot.value != "00:00") {
        final parts = (offTimeSnapshot.value as String).split(":");
        setState(() {
          offTime = TimeOfDay(
            hour: int.parse(parts[0]),
            minute: int.parse(parts[1]),
          );
        });
      }

      // Lấy trạng thái của isOn
      final statusSnapshot = await _dbRef.child('$deviceKey/status').get();
      if (statusSnapshot.exists) {
        setState(() {
          isOn = statusSnapshot.value as bool;
        });
      }
    } catch (e) {
      print("Error fetching device settings: $e");
    }
  }

  Future<void> _pickTime(BuildContext context, bool isOnTime) async {
    TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child ?? Container(),
        );
      },
    );

    if (pickedTime != null) {
      setState(() {
        if (isOnTime) {
          onTime = pickedTime;
        } else {
          offTime = pickedTime;
        }
        _updateAutoSettings(); // Cập nhật Firebase khi đặt thời gian
      });
    }
  }

  void _updateAutoSettings() {
    // Chuyển đổi TimeOfDay thành chuỗi 24 giờ dạng "HH:mm"
    String formatTimeOfDay(TimeOfDay? time) {
      if (time == null) return "00:00";
      final String hour = time.hour.toString().padLeft(2, '0');
      final String minute = time.minute.toString().padLeft(2, '0');
      return "$hour:$minute";
    }

    // Cập nhật Firebase với giá trị auto, ontime, và offtime
    final String deviceKey = widget.label.toLowerCase().replaceAll(' ', '');
    _dbRef.child(deviceKey).update({
      'auto': isAuto,
      'ontime': formatTimeOfDay(onTime),
      'offtime': formatTimeOfDay(offTime),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.label)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.iconData,
              size: 100,
              color: isOn ? Colors.yellow : Colors.grey,
            ),
            const SizedBox(height: 20),
            Text(
              isOn ? "Status: ON" : "Status: OFF",
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  isOn = !isOn;
                  widget.onToggle(isOn);

                  // Cập nhật trạng thái trong Firebase
                  final String deviceKey = widget.label.toLowerCase().replaceAll(' ', '');
                  _dbRef.child('$deviceKey/status').set(isOn);

                  // Thêm lịch sử vào "notifications"
                  _dbRef.child('notifications').push().set({
                    'title': 'Device ${widget.label}',
                    'body': isOn ? 'Turned ON' : 'Turned OFF',
                    'timestamp': DateTime.now().millisecondsSinceEpoch, // Lưu thời gian
                  });
                });
              },
              child: Text(isOn ? "Turn OFF" : "Turn ON"),
            ),
            const SizedBox(height: 20),
            SwitchListTile(
              title: const Text("Auto Mode"),
              value: isAuto,
              onChanged: (value) {
                setState(() {
                  isAuto = value;
                  if (!isAuto) {
                    onTime = null;
                    offTime = null;
                  }
                  _updateAutoSettings(); // Cập nhật chế độ auto lên Firebase
                });
              },
            ),
            if (isAuto) _buildAutoTimeForm(), // Hiển thị form khi auto là true
          ],
        ),
      ),
    );
  }

  Widget _buildAutoTimeForm() {
    return Column(
      children: [
        ListTile(
          title: Text("On Time: ${onTime?.format(context) ?? "Not Set"}"),
          trailing: IconButton(
            icon: const Icon(Icons.access_time),
            onPressed: () => _pickTime(context, true),
          ),
        ),
        ListTile(
          title: Text("Off Time: ${offTime?.format(context) ?? "Not Set"}"),
          trailing: IconButton(
            icon: const Icon(Icons.access_time),
            onPressed: () => _pickTime(context, false),
          ),
        ),
      ],
    );
  }
}
