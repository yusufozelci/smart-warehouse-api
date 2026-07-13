import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class WorkerManagementPage extends StatefulWidget {
  final String initialFilter;
  const WorkerManagementPage({super.key, this.initialFilter = "ALL"});

  @override
  State<WorkerManagementPage> createState() => _WorkerManagementPageState();
}

class _WorkerManagementPageState extends State<WorkerManagementPage> {
  final Color primaryColor = const Color(0xFF1A237E);
  List<dynamic> _workers = [];
  bool _isLoading = true;

  String get baseUrl {
    if (kIsWeb) return "http://localhost:8080";
    if (Platform.isAndroid) return "http://10.0.2.2:8080";
    return "http://localhost:8080";
  }

  @override
  void initState() {
    super.initState();
    _fetchWorkers();
  }

  List<dynamic> get filteredWorkers {
    if (widget.initialFilter == "ACTIVE_ONLY") {
      return _workers.where((w) => w['role'] == 'WORKER').toList();
    }
    return _workers;
  }

  Future<void> _fetchWorkers() async {
    setState(() => _isLoading = true);
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/workers'),
        headers: {"Content-Type": "application/json", if (token != null) "Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        setState(() {
          _workers = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        throw Exception("Veri çekilemedi: ${response.statusCode}");
      }
    } catch (e) {
      print("Hata: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteWorker(int id, String name) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Dikkat!"),
        content: Text("$name adlı personeli silmek istediğinize emin misiniz?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("İptal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Sil", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      final response = await http.delete(
        Uri.parse('$baseUrl/api/v1/workers/$id'),
        headers: {"Content-Type": "application/json", if (token != null) "Authorization": "Bearer $token"},
      );

      if (response.statusCode == 204 || response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Personel başarıyla silindi!"), backgroundColor: Colors.green));
        _fetchWorkers();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response.body), backgroundColor: Colors.redAccent, duration: const Duration(seconds: 4)));
      }
    } catch (e) {
      print("Hata: $e");
    }
  }

  void _showEditWorkerDialog(Map<String, dynamic> worker) {
    final firstNameCtrl = TextEditingController(text: worker['firstName']);
    final lastNameCtrl = TextEditingController(text: worker['lastName']);
    final emailCtrl = TextEditingController(text: worker['email']);
    String _selectedRole = worker['role'] ?? "WORKER";
    bool _isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: Row(
                  children: [
                    Icon(Icons.edit, color: primaryColor),
                    const SizedBox(width: 10),
                    Text("Düzenle: ${worker['firstName']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                content: SingleChildScrollView(
                  child: SizedBox(
                    width: 400,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(controller: firstNameCtrl, decoration: const InputDecoration(labelText: "Adı", prefixIcon: Icon(Icons.person_outline))),
                        const SizedBox(height: 10),
                        TextField(controller: lastNameCtrl, decoration: const InputDecoration(labelText: "Soyadı", prefixIcon: Icon(Icons.badge_outlined))),
                        const SizedBox(height: 10),
                        TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: "Email", prefixIcon: Icon(Icons.email_outlined))),
                        const SizedBox(height: 15),
                        DropdownButtonFormField<String>(
                          value: _selectedRole,
                          decoration: const InputDecoration(labelText: "Rolü", prefixIcon: Icon(Icons.security)),
                          items: const [
                            DropdownMenuItem(value: "WORKER", child: Text("Saha Personeli (Worker)")),
                            DropdownMenuItem(value: "ADMIN", child: Text("Yönetici (Admin)")),
                          ],
                          onChanged: (val) {
                            if (val != null) setDialogState(() => _selectedRole = val);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                    child: const Text("İptal", style: TextStyle(color: Colors.grey)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
                    onPressed: _isSubmitting ? null : () async {
                      setDialogState(() => _isSubmitting = true);

                      try {
                        SharedPreferences prefs = await SharedPreferences.getInstance();
                        String? token = prefs.getString('token');

                        final response = await http.put(
                          Uri.parse('$baseUrl/api/v1/workers/${worker['id']}'),
                          headers: {
                            "Content-Type": "application/json",
                            if (token != null) "Authorization": "Bearer $token"
                          },
                          body: jsonEncode({
                            "firstName": firstNameCtrl.text,
                            "lastName": lastNameCtrl.text,
                            "email": emailCtrl.text,
                            "role": _selectedRole,
                          }),
                        );

                        if (response.statusCode == 200 || response.statusCode == 204) {
                          if (!context.mounted) return;
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Personel bilgileri güncellendi!"), backgroundColor: Colors.green));
                          _fetchWorkers();
                        } else {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: ${response.statusCode}"), backgroundColor: Colors.red));
                        }
                      } catch (e) {
                        print("Güncelleme Hatası: $e");
                      } finally {
                        setDialogState(() => _isSubmitting = false);
                      }
                    },
                    child: _isSubmitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text("Kaydet"),
                  ),
                ],
              );
            }
        );
      },
    );
  }

  void _showAddWorkerDialog() {
    final TextEditingController _firstNameCtrl = TextEditingController();
    final TextEditingController _lastNameCtrl = TextEditingController();
    final TextEditingController _emailCtrl = TextEditingController();
    final TextEditingController _passwordCtrl = TextEditingController();
    String _selectedRole = "WORKER";
    bool _isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Icon(Icons.person_add, color: primaryColor),
                  const SizedBox(width: 10),
                  const Text("Yeni Personel Ekle", style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 400,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(controller: _firstNameCtrl, decoration: const InputDecoration(labelText: "Adı", prefixIcon: Icon(Icons.person_outline))),
                      const SizedBox(height: 10),
                      TextField(controller: _lastNameCtrl, decoration: const InputDecoration(labelText: "Soyadı", prefixIcon: Icon(Icons.badge_outlined))),
                      const SizedBox(height: 10),
                      TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: "Email (Kullanıcı Adı)", prefixIcon: Icon(Icons.email_outlined))),
                      const SizedBox(height: 10),
                      TextField(controller: _passwordCtrl, obscureText: true, decoration: const InputDecoration(labelText: "Şifre", prefixIcon: Icon(Icons.lock_outline))),
                      const SizedBox(height: 15),
                      DropdownButtonFormField<String>(
                        value: _selectedRole,
                        decoration: const InputDecoration(labelText: "Rolü", prefixIcon: Icon(Icons.security)),
                        items: const [
                          DropdownMenuItem(value: "WORKER", child: Text("Saha Personeli (Worker)")),
                          DropdownMenuItem(value: "ADMIN", child: Text("Yönetici (Admin)")),
                        ],
                        onChanged: (val) {
                          if (val != null) setDialogState(() => _selectedRole = val);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text("İptal", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
                  onPressed: _isSubmitting
                      ? null
                      : () async {
                    if (_firstNameCtrl.text.isEmpty || _lastNameCtrl.text.isEmpty || _emailCtrl.text.isEmpty || _passwordCtrl.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen tüm alanları doldurun!"), backgroundColor: Colors.red));
                      return;
                    }

                    setDialogState(() => _isSubmitting = true);

                    try {
                      SharedPreferences prefs = await SharedPreferences.getInstance();
                      String? token = prefs.getString('token');

                      final response = await http.post(
                        Uri.parse('$baseUrl/api/v1/workers'),
                        headers: {"Content-Type": "application/json", if (token != null) "Authorization": "Bearer $token"},
                        body: jsonEncode({
                          "firstName": _firstNameCtrl.text,
                          "lastName": _lastNameCtrl.text,
                          "email": _emailCtrl.text,
                          "password": _passwordCtrl.text,
                          "role": _selectedRole
                        }),
                      );

                      if (response.statusCode == 200 || response.statusCode == 201) {
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Personel başarıyla eklendi!"), backgroundColor: Colors.green));
                        _fetchWorkers();
                      } else {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: ${response.body}"), backgroundColor: Colors.red));
                      }
                    } catch (e) {
                      print("Ekleme Hatası: $e");
                    } finally {
                      setDialogState(() => _isSubmitting = false);
                    }
                  },
                  child: _isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("Kaydet"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(
            widget.initialFilter == "ACTIVE_ONLY" ? "Aktif Saha Personelleri" : "Personel Yönetimi",
            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
              icon: const Icon(Icons.person_add),
              label: const Text("Yeni Ekle"),
              onPressed: _showAddWorkerDialog,
            ),
          )
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : filteredWorkers.isEmpty
          ? const Center(child: Text("Sistemde kayıtlı personel bulunamadı.", style: TextStyle(fontSize: 18, color: Colors.grey)))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredWorkers.length,
        itemBuilder: (context, index) {
          final worker = filteredWorkers[index];
          final String role = worker['role'] ?? 'BİLİNMİYOR';
          final bool isAdmin = role == 'ADMIN';

          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              leading: CircleAvatar(
                radius: 25,
                backgroundColor: isAdmin ? Colors.red.shade100 : Colors.blue.shade100,
                child: Icon(isAdmin ? Icons.admin_panel_settings : Icons.person, color: isAdmin ? Colors.red : primaryColor),
              ),
              title: Text("${worker['firstName']} ${worker['lastName']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: isAdmin ? Colors.red.shade50 : Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Text(isAdmin ? "YÖNETİCİ" : "SAHA PERSONELİ", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isAdmin ? Colors.red : Colors.green)),
                  ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => _showEditWorkerDialog(worker),
                    tooltip: "Düzenle",
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _deleteWorker(worker['id'], worker['firstName']),
                    tooltip: "Personeli Sil",
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}