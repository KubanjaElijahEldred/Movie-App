import 'package:flutter/material.dart';
import 'package:movies/screens/elijah_dashboard.dart';
import 'package:movies/theme/theme_state.dart';
import 'package:provider/provider.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ThemeState>(
      create: (_) => ThemeState(),
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
