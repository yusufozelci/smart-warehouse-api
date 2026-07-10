import 'package:flutter/material.dart';
import 'package:smart_warehouse_app/services/auth_service.dart';
import 'package:smart_warehouse_app/login_page.dart';
import '../admin_home_page.dart';
import '../services/websocket_service.dart';

class AdminMainLayout extends StatefulWidget {
  const AdminMainLayout({super.key});

  @override
  State<AdminMainLayout> createState() => _AdminMainLayoutState();
}

class _AdminMainLayoutState extends State<AdminMainLayout> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const AdminHomePage(),
    const Center(child: Text("Personel Performans Paneli", style: TextStyle(fontSize: 24))),
    const Center(child: Text("Kritik Stok ve Raf Takibi", style: TextStyle(fontSize: 24))),
    const Center(child: Text("Canlı Görev ve Rota Haritası", style: TextStyle(fontSize: 24))),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _handleLogout() async {
    WebSocketService.instance.stompClient?.deactivate();
    WebSocketService.instance.messages.clear();
    await AuthService().logout();
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => LoginPage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isWebOrTablet = screenWidth >= 800;

    return Scaffold(
      body: isWebOrTablet
          ? _buildWebLayout()
          : _pages[_selectedIndex],

      bottomNavigationBar: isWebOrTablet
          ? null
          : _buildMobileBottomNav(),
    );
  }

  Widget _buildWebLayout() {
    return Row(
      children: [
        NavigationRail(
          backgroundColor: Colors.indigo.shade900,
          selectedIndex: _selectedIndex,
          onDestinationSelected: _onItemTapped,
          unselectedIconTheme: const IconThemeData(color: Colors.white70, opacity: 1),
          selectedIconTheme: const IconThemeData(color: Colors.amberAccent),
          unselectedLabelTextStyle: const TextStyle(color: Colors.white70),
          selectedLabelTextStyle: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold),
          extended: MediaQuery.of(context).size.width >= 1000,
          destinations: const [
            NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: Text('Genel Durum')),
            NavigationRailDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: Text('Personeller')),
            NavigationRailDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory), label: Text('Stok Yönetimi')),
            NavigationRailDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: Text('Görev & Rotalar')),
          ],
          trailing: Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: IconButton(
                  icon: const Icon(Icons.logout, color: Colors.redAccent),
                  tooltip: "Çıkış Yap",
                  onPressed: _handleLogout,
                ),
              ),
            ),
          ),
        ),
        const VerticalDivider(thickness: 1, width: 1),
        Expanded(
          child: Container(
            color: Colors.grey.shade100,
            child: _pages[_selectedIndex],
          ),
        )
      ],
    );
  }

  Widget _buildMobileBottomNav() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: _onItemTapped,
      backgroundColor: Colors.white,
      selectedItemColor: Colors.redAccent,
      unselectedItemColor: Colors.grey,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Özet'),
        BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Personel'),
        BottomNavigationBarItem(icon: Icon(Icons.inventory_2), label: 'Stok'),
        BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Rotalar'),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    WebSocketService.instance.connect("ws://localhost:8080/ws-warehouse");
  }
}