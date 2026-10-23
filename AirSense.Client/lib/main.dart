import 'package:flutter/material.dart';
import 'screens/connect_screen.dart';
import 'services/network_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final networkService = NetworkService();

  runApp(AirSenseApp(network: networkService));
}

class AirSenseApp extends StatelessWidget {
  final NetworkService network;

  const AirSenseApp({super.key, required this.network});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AirSense',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F1117),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00C8FF),
          secondary: Color(0xFF003791),
          surface: Color(0xFF161A23),
        ),
        useMaterial3: true,
      ),
      home: ConnectScreen(network: network),
    );
  }
}
