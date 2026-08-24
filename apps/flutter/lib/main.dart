import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meckchat/providers/presence_provider.dart';
import 'package:meckchat/screens/home/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MeckChatApp());
}

class MeckChatApp extends StatelessWidget {
  const MeckChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => PresenceProvider()..initialize(),
        ),
      ],
      child: MaterialApp(
        title: 'MeckChat',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF0F172A),
          primaryColor: const Color(0xFF38BDF8),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF38BDF8),
            secondary: Color(0xFF818CF8),
            surface: Color(0xFF1E293B),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1E293B),
            elevation: 0,
            centerTitle: false,
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
