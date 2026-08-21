import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/chat_provider.dart';
import 'providers/file_transfer_provider.dart';
import 'providers/presence_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/home/home_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'services/meckchat_core_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load saved device identity from local persistent storage
  final service = MeckChatCoreService();
  final bool isAlreadyOnboarded = await service.loadSavedIdentity();

  runApp(MeckChatApp(isAlreadyOnboarded: isAlreadyOnboarded));
}

class MeckChatApp extends StatelessWidget {
  final bool isAlreadyOnboarded;

  const MeckChatApp({
    super.key,
    required this.isAlreadyOnboarded,
  });

  @override
  Widget build(BuildContext context) {
    final service = MeckChatCoreService();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) {
          final presence = PresenceProvider();
          if (service.localIdentity != null) {
            presence.setLocalIdentity(service.localIdentity!);
          }
          return presence;
        }),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => FileTransferProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
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
        home: isAlreadyOnboarded ? const HomeScreen() : const OnboardingScreen(),
      ),
    );
  }
}
