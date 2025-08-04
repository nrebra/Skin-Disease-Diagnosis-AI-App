import 'package:flutter/material.dart';

import 'package:skincancer/pages/Home/HomePage.dart';
import 'package:skincancer/pages/Community/CommunityPage.dart';
import 'package:skincancer/pages/A%C4%B0/chat_page.dart';
import 'package:skincancer/pages/Profile/ProfilePage.dart';

class PatientControllerPage extends StatefulWidget {
  final String userName;
  const PatientControllerPage({Key? key, required this.userName})
      : super(key: key);

  @override
  State<PatientControllerPage> createState() => _PatientControllerPageState();
}

class _PatientControllerPageState extends State<PatientControllerPage> {
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
        if (_selectedIndex == 2) {
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
        // drawer: const CustomDrawer(),
        resizeToAvoidBottomInset: false,
        body: PageView(
          controller: _pageController,
          physics: NeverScrollableScrollPhysics(),
          onPageChanged: (index) => setState(() => _selectedIndex = index),
          children: [
            HomeScreen(userName: widget.userName),
            CommunityScreen(),
            ChatScreen(),
            ProfileScreen(),
          ],
        ),
        bottomNavigationBar: _selectedIndex == 2
            ? Container(height: 0, width: 0)
            : Container(
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    height: 75,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child:
                              _buildNavItem(0, Icons.home_rounded, "Ana Sayfa"),
                        ),
                        Expanded(
                          child: _buildNavItem(
                              1, Icons.people_rounded, "Community"),
                        ),
                        Expanded(
                          child: _buildNavItem(
                              2, Icons.chat_bubble_rounded, "ChatBot"),
                        ),
                        Expanded(
                          child:
                              _buildNavItem(3, Icons.person_rounded, "Profil"),
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
            ? const BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Color(0xFF095C5C),
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
              color: isSelected ? const Color(0xFF095C5C) : Colors.grey,
              size: 25,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isSelected ? const Color(0xFF095C5C) : Colors.grey,
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
