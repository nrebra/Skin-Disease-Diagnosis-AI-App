import 'package:flutter/material.dart';
import 'package:skincancer/pages/Camera/CameraPage.dart';
import 'package:skincancer/pages/Community/CommunityPage.dart';
import 'package:skincancer/pages/Home/HomePage.dart';
import 'package:skincancer/pages/Profile/ProfilePage.dart';
import 'package:skincancer/style/color.dart';
import 'Aİ/chat_page.dart';

class ControllerPage extends StatefulWidget {
  final String userName;
  const ControllerPage({super.key, required this.userName});

  @override
  State<ControllerPage> createState() => _ControllerPageState();
}

class _ControllerPageState extends State<ControllerPage> {
  final PageController _pageController = PageController();
  int _selectedIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Öncelikle klavye açık mı kontrol et
        final FocusScopeNode currentFocus = FocusScope.of(context);
        if (!currentFocus.hasPrimaryFocus &&
            currentFocus.focusedChild != null) {
          // Klavye açıksa, sadece klavyeyi kapat
          FocusManager.instance.primaryFocus?.unfocus();
          return false; // Geri tuşunu engelle
        }

        // ChatBot sayfası açıksa ve geri tuşuna basıldıysa, özel işlem yapmadan izin ver
        if (_selectedIndex == 3) {
          return true; // ChatBot sayfası kendi içinde geri tuşunu ele alacak
        }

        // Diğer durumlarda, kullanıcıya çıkmak isteyip istemediğini sor
        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Uygulamadan çıkmak istiyor musunuz?'),
              content: const Text('Çıkış yapmak istediğinize emin misiniz?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Hayır'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Evet'),
                ),
              ],
            );
          },
        );

        return shouldPop ?? false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: false,
        body: PageView(
          controller: _pageController,
          onPageChanged: (index) => setState(() => _selectedIndex = index),
          children: [
            HomeScreen(userName: widget.userName),
            CommunityScreen(),
            CameraScreen(),
            ChatScreen(),
            ProfileScreen(),
          ],
        ),
        floatingActionButton: Container(
          height: 65,
          width: 60,
          margin: const EdgeInsets.all(10),
          child: FloatingActionButton(
            heroTag: 'controller_camera_button',
            backgroundColor: primaryColor.withOpacity(1),
            elevation: _selectedIndex == 2 ? 8 : 4,
            onPressed: () => _onItemTapped(2),
            child: Icon(
              Icons.camera_rounded,
              size: 35,
              color: Colors.white,
            ),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 15,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              height: 75,
              child: Stack(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child:
                            _buildNavItem(0, Icons.home_rounded, "Ana Sayfa"),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 15),
                          child: _buildNavItem(
                              1, Icons.people_rounded, "Community"),
                        ),
                      ),
                      const SizedBox(width: 30),
                      Expanded(
                        child: _buildNavItem(
                            3, Icons.chat_bubble_rounded, "ChatBot"),
                      ),
                      Expanded(
                        child: _buildNavItem(4, Icons.person_rounded, "Profil"),
                      ),
                    ],
                  ),
                  if (_selectedIndex != 2)
                    Positioned.fill(
                      child: Center(
                        child: Container(
                          width: 45,
                          height: 45,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    bool isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () => _onItemTapped(index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: isSelected
            ? BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: navBarSelectedColor,
                    width: 2.5,
                  ),
                ),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? navBarSelectedColor : navBarUnselectedColor,
              size: 25,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isSelected ? navBarSelectedColor : navBarUnselectedColor,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
