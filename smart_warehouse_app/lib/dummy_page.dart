
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class DummyPage extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;

  const DummyPage({super.key, required this.title, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: color,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 100, color: color.withOpacity(0.5)),
            const SizedBox(height: 20),
            Text(
              "$title Modülü",
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text("Bu sayfanın verileri yakında eklenecektir..."),
          ],
        ),
      ),
    );
  }
}