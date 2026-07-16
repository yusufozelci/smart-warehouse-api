import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:smart_warehouse_app/reset_password_page.dart';

class ForgotPasswordPage extends StatefulWidget {
  final String baseUrl;
  const ForgotPasswordPage({super.key, required this.baseUrl});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _contactController = TextEditingController();
  String _selectedMethod = "EMAIL";
  bool _isLoading = false;
  bool _isOtpSent = false;
  final _otpController = TextEditingController();

  final defaultPinTheme = PinTheme(
    width: 56, height: 56,
    textStyle: const TextStyle(fontSize: 20, color: Color(0xFF1A237E), fontWeight: FontWeight.bold),
    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
  );

  Future<void> _sendOtp() async {
    setState(() => _isLoading = true);
    final response = await http.post(
      Uri.parse('${widget.baseUrl}/api/auth/forgot-password'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "contactInfo": _contactController.text,
        "deliveryMethod": _selectedMethod
      }),
    );

    setState(() => _isLoading = false);
    if (response.statusCode == 200) {
      setState(() => _isOtpSent = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hata: Gönderim başarısız veya kullanıcı bulunamadı!")));
    }
  }

  Future<void> _verifyOtp() async {
    setState(() => _isLoading = true);
    final response = await http.post(
      Uri.parse('${widget.baseUrl}/api/auth/verify-otp'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "contactInfo": _contactController.text,
        "otpCode": _otpController.text
      }),
    );

    setState(() => _isLoading = false);
    if (response.statusCode == 200) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ResetPasswordPage(baseUrl: widget.baseUrl, contactInfo: _contactController.text)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hata: Kod hatalı veya süresi dolmuş!")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Şifremi Unuttum"),
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
            padding: const EdgeInsets.all(24.0),
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
                        child: const Icon(Icons.lock_reset, size: 60, color: Color(0xFF1A237E)),
                      ),
                      const SizedBox(height: 24),
                      const Text("Doğrulama", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                      const SizedBox(height: 8),
                      Text(
                        _isOtpSent ? "Lütfen 6 haneli kodu giriniz" : "Şifrenizi sıfırlamak için bir yöntem seçin",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 32),

                      if (!_isOtpSent) ...[
                        TextField(
                            controller: _contactController,
                            decoration: InputDecoration(
                                labelText: "E-posta veya Telefon",
                                prefixIcon: const Icon(Icons.contact_mail_outlined),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))
                            )
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _selectedMethod,
                          decoration: InputDecoration(
                            labelText: "Gönderim Yöntemi",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(Icons.send_outlined),
                          ),
                          items: ["EMAIL", "SMS"].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                          onChanged: (v) => setState(() => _selectedMethod = v!),
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A237E), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                onPressed: _isLoading ? null : _sendOtp,
                                child: _isLoading
                                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Text("Kod Gönder", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
                            )
                        )
                      ] else ...[
                        Pinput(controller: _otpController, length: 6, defaultPinTheme: defaultPinTheme),
                        const SizedBox(height: 32),
                        SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                onPressed: _isLoading ? null : _verifyOtp,
                                child: _isLoading
                                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Text("Doğrula", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
                            )
                        )
                      ]
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