import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'history_screen.dart';
import 'profile_screen.dart';
import 'recommendations_screen.dart';
import 'surveys_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Seguimiento al Graduado'),
          actions: [
            IconButton(
              tooltip: 'Cerrar sesión',
              onPressed: () => Supabase.instance.client.auth.signOut(),
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Mi espacio',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            const Text(
                'Consulta tu perfil y participa en el seguimiento a graduados.'),
            const SizedBox(height: 20),
            const _Item('Mi perfil', 'Consulta y actualiza tus datos.',
                Icons.person_outline, ProfileScreen()),
            const _Item('Encuestas', 'Consulta encuestas disponibles.',
                Icons.assignment_outlined, SurveysScreen()),
            const _Item(
                'Responder encuesta',
                'Completa una encuesta disponible.',
                Icons.edit_note_outlined,
                SurveysScreen()),
            const _Item('Historial', 'Revisa tus encuestas respondidas.',
                Icons.history, HistoryScreen()),
            _Item('Recomendaciones', 'Envía sugerencias y consulta su estado.',
                Icons.lightbulb_outline, const RecommendationsScreen()),
          ],
        ),
      );
}

class _Item extends StatelessWidget {
  const _Item(this.title, this.subtitle, this.icon, this.destination);
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget destination;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => destination)),
        ),
      );
}
