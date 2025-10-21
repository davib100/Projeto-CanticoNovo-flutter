import 'package:flutter/material.dart';
import 'package:myapp/core/app_orchestrator.dart';

class HomePage extends StatelessWidget {
  final AppOrchestrator orchestrator;

  const HomePage({super.key, required this.orchestrator});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cântico Novo'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'Welcome to Cântico Novo!',
            ),
          ],
        ),
      ),
    );
  }
}
