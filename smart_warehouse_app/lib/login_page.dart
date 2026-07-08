import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_warehouse_app/worker_home_page.dart';
import 'admin_home_page.dart';
import 'services/auth_service.dart';

class LoginPage extends StatelessWidget {
  final TextEditingController _userCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  final AuthService _auth = AuthService();

  LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Akıllı Depo Giriş")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: _userCtrl, decoration: const InputDecoration(labelText: "Kullanıcı Adı")),
            TextField(controller: _passCtrl, decoration: const InputDecoration(labelText: "Şifre"), obscureText: true),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                bool success = await _auth.login(_userCtrl.text, _passCtrl.text);
                if (success) {
                  SharedPreferences prefs = await SharedPreferences.getInstance();
                  String? role = prefs.getString('role');

                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Giriş Başarılı!")));

                  if (role == 'ADMIN') {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const AdminHomePage()),
                    );
                  } else {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const WorkerHomePage()),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Giriş Başarısız!")));
                }
              },
              child: const Text("Giriş Yap"),
            )
          ],
        ),
      ),
    );
  }
}