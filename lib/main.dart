import 'package:flutter/material.dart';
import 'package:movies/screens/elijah_dashboard.dart';
import 'package:movies/services/auth_service.dart';
import 'package:movies/theme/theme_state.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.initialize();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeState>(create: (_) => ThemeState()),
        ChangeNotifierProvider<AuthService>(create: (_) => AuthService()),
      ],
      child: MaterialApp(
        title: 'Play It - Movie Streaming',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          primarySwatch: Colors.teal,
          scaffoldBackgroundColor: Color(0xFF0D0F1F),
          canvasColor: Colors.transparent,
        ),
        home: ElijahDashboard(),
      ),
    );
  }
}
