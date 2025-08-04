import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skincancer/pages/auth/BeginPage.dart';
import 'package:skincancer/pages/Community/CommunityPage.dart';
import 'package:skincancer/pages/auth/LoginPage.dart';
import 'package:skincancer/provider/post_provider.dart';
import 'package:skincancer/service/api_service.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:skincancer/pages/Camera/CameraPage.dart';
import 'package:skincancer/pages/chat/ChatPage.dart';
import 'package:skincancer/pages/Home/HomePage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR', null);

  // Configure Flutter to handle graphics rendering more gracefully
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details, forceReport: true);
  };

  try {
    // Initialize API service
    final apiService = ApiService();

    // Load and validate token
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token != null && token.isNotEmpty) {
      try {
        // Initialize token and validate it
        await apiService.initializeToken();
      } catch (e) {
        // Clear invalid token
        await prefs.remove('token');
        await apiService.setToken(null);
      }
    }

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => PostProvider()),
        ],
        child: MyApp(),
      ),
    );
  } catch (e) {
    // Clear any invalid tokens
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    runApp(MyApp());
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MainNavigator(),
      routes: {
        '/login': (context) => LoginScreen(),
        '/home': (context) => HomeScreen(userName: "Kullanıcı"),
        '/camera': (context) => CameraScreen(),
        '/chat': (context) => ChatPage(
              receiverId: "1",
              receiverName: "Chatbot",
              receiverSurname: "AI",
            ),
        '/community': (context) => CommunityScreen(),
      },
    );
  }
}

class MainNavigator extends StatelessWidget {
  const MainNavigator({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // Geri tuşuna basıldığında uygulamanın kapanmasını engelle
      onWillPop: () async {
        // Öncelikle klavye açık mı kontrol et
        final FocusScopeNode currentFocus = FocusScope.of(context);
        if (!currentFocus.hasPrimaryFocus &&
            currentFocus.focusedChild != null) {
          // Klavye açıksa, sadece klavyeyi kapat
          FocusManager.instance.primaryFocus?.unfocus();
          return false; // Geri tuşunu engelle
        }

        // Ana sayfada olup olmadığını kontrol et
        final isFirstRoute = ModalRoute.of(context)?.isFirst ?? false;

        if (isFirstRoute) {
          // Çıkış yapmak isteyip istemediğini sor
          final shouldPop = await showDialog<bool>(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: const Text('Uygulamadan çıkmak istiyor musunuz?'),
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
        }

        // Ana sayfada değilse normal geri davranışına izin ver
        return true;
      },
      child: BeginScreen(),
    );
  }
}
