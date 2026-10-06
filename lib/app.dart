import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/configuracion_aplicacion.dart';
import 'controllers/controlador_preferencias.dart';
import 'screens/control_acceso.dart';
import 'screens/pantalla_configuracion_requerida.dart';

class ProyectoFinalApp extends StatelessWidget {
  const ProyectoFinalApp({super.key});

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<PreferencesController>();
    final config = context.watch<AppConfig>();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Seguimiento al Graduado',
      themeMode: prefs.themeMode,
      theme: ThemeData(
          colorSchemeSeed: Colors.indigo,
          useMaterial3: true,
          brightness: Brightness.light),
      darkTheme: ThemeData(
          colorSchemeSeed: Colors.indigo,
          useMaterial3: true,
          brightness: Brightness.dark),
      routes: {'/admin/dashboard': (_) => const AuthGate(dashboardRoute: true)},
      home: config.hasSupabaseConfig
          ? const AuthGate()
          : const SetupRequiredScreen(),
    );
  }
}
