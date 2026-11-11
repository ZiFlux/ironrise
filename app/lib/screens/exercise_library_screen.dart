import 'package:flutter/material.dart';

import '../widgets/exercise_picker.dart';

/// Справочник упражнений (экран 6): поиск, фильтр по части тела, доли нагрузки.
class ExerciseLibraryScreen extends StatelessWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Справочник упражнений')),
      body: ExerciseBrowser(
        showInfoButton: false,
        onTap: (e) => showExerciseDetails(context, e),
      ),
    );
  }
}
