import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ResetPasswordPage extends StatefulWidget {
  final String baseUrl;
  final String contactInfo;
  const ResetPasswordPage({super.key, required this.baseUrl, required this.contactInfo});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _passController = TextEditingController();
  final _passConfirmController = TextEditingController();
  bool _isLoading = false;

  Future<void> _resetPassword() async {
    if (_passController.text.isEmpty || _passController.text != _passConfirmController.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Şifreler eşleşmiyor veya boş olamaz!"), backgroundColor: Colors.redAccent));
      return;
    }

    setState(() => _isLoading = true);

    final response = await http.post(
      Uri.parse('${widget.baseUrl}/api/auth/reset-password'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "contactInfo": widget.contactInfo,
        "newPassword": _passController.text
      }),
    );

    setState(() => _isLoading = false);

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Şifre başarıyla yenilendi!"),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.popUntil(context, (route) => route.isFirst);
    } else {
      String errorMessage = "Bir hata oluştu. Lütfen tekrar deneyin.";

      try {
        final body = jsonDecode(response.body);
        if (body["error"] != null) {
          errorMessage = body["error"];
        }
      } catch (_) {}

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Yeni Şifre"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
                        child: const Icon(Icons.vpn_key_rounded, size: 60, color: Color(0xFF1A237E)),
                      ),
                      const SizedBox(height: 24),
                      const Text("Şifre Belirleme", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                      const SizedBox(height: 8),
                      Text("Hesabınız için yeni bir şifre oluşturun", textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                      const SizedBox(height: 32),

                      TextField(
                          controller: _passController,
                          obscureText: true,
                          decoration: InputDecoration(
                              labelText: "Yeni Şifre",
                              prefixIcon: const Icon(Icons.lock_outline),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))
                          )
                      ),
                      const SizedBox(height: 16),

                      TextField(
                          controller: _passConfirmController,
                          obscureText: true,
                          decoration: InputDecoration(
                              labelText: "Şifre Tekrar",
                              prefixIcon: const Icon(Icons.lock_reset_outlined),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))
                          )
                      ),
                      const SizedBox(height: 32),

                      SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A237E), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                              onPressed: _isLoading ? null : _resetPassword,
                              child: _isLoading
                                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Text("Kaydet ve Giriş Yap", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
                          )
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}