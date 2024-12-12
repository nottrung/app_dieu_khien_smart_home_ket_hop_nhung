import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'login_page.dart';

class MultiFunctionButton extends StatelessWidget {
  const MultiFunctionButton({Key? key}) : super(key: key);

  void _showEndDrawer(BuildContext context) {
    Scaffold.of(context).openEndDrawer(); // Mở EndDrawer
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.menu), // Biểu tượng ba gạch ngang
      onPressed: () => _showEndDrawer(context),
    );
  }
}