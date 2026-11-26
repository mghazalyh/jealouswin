import 'package:flutter/material.dart';

void main() => runApp(const JealouswinApp());

class JealouswinApp extends StatefulWidget {
  const JealouswinApp({super.key});

  @override
  State<JealouswinApp> createState() => _JealouswinAppState();
}

class _JealouswinAppState extends State<JealouswinApp> {
  bool _dark = false;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Jealouswin',
    debugShowCheckedModeBanner: false,
    themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
    theme: _theme(Brightness.light),
    darkTheme: _theme(Brightness.dark),
    home: StarterHome(
      dark: _dark,
      toggleTheme: () => setState(() => _dark = !_dark),
    ),
  );

  ThemeData _theme(Brightness brightness) => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF5254CF),
      brightness: brightness,
    ),
    scaffoldBackgroundColor: brightness == Brightness.light
        ? const Color(0xFFF7F8FC)
        : const Color(0xFF111321),
  );
}

class StarterHome extends StatefulWidget {
  const StarterHome({super.key, required this.dark, required this.toggleTheme});

  final bool dark;
  final VoidCallback toggleTheme;

  @override
  State<StarterHome> createState() => _StarterHomeState();
}

class _StarterHomeState extends State<StarterHome> {
  final _input = TextEditingController();
  final _tasks = <({String title, bool done})>[
    (title: 'Choose the first feature', done: false),
    (title: 'Make this space your own', done: false),
    (title: 'Share your first release', done: false),
  ];

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _addTask() {
    final title = _input.text.trim();
    if (title.isEmpty) return;
    setState(() => _tasks.add((title: title, done: false)));
    _input.clear();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final completed = _tasks.where((task) => task.done).length;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1060),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colors.primary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.auto_awesome,
                          color: colors.onPrimary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'jealouswin',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: widget.dark
                            ? 'Use light theme'
                            : 'Use dark theme',
                        onPressed: widget.toggleTheme,
                        icon: Icon(
                          widget.dark ? Icons.light_mode : Icons.dark_mode,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 64),
                  Text(
                    'YOUR NEXT CHAPTER',
                    style: TextStyle(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Great ideas start\nwith a little space.',
                    style: TextStyle(
                      fontSize: 46,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'A fresh canvas for what comes next. Pick a small goal,\n'
                    'make it happen, and build from there.',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 17,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 40),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final checklist = _checklist(context, completed);
                      final welcome = _welcome(context);
                      if (constraints.maxWidth < 720) {
                        return Column(
                          children: [
                            checklist,
                            const SizedBox(height: 20),
                            welcome,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: checklist),
                          const SizedBox(width: 24),
                          Expanded(flex: 2, child: welcome),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 40),
                  Text(
                    'Made for your next idea.  /  Flutter web starter',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _checklist(BuildContext context, int completed) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: colors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your first steps',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text('$completed of ${_tasks.length} complete'),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: completed / _tasks.length,
              minHeight: 6,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 16),
            for (var index = 0; index < _tasks.length; index++)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _tasks[index].done,
                title: Text(
                  _tasks[index].title,
                  style: TextStyle(
                    decoration: _tasks[index].done
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                  ),
                ),
                onChanged: (done) => setState(
                  () => _tasks[index] = (
                    title: _tasks[index].title,
                    done: done ?? false,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    maxLength: 120,
                    decoration: const InputDecoration(
                      labelText: 'Add your next step',
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                    onSubmitted: (_) => _addTask(),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  tooltip: 'Add step',
                  onPressed: _addTask,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'This starter keeps your list for this session only.',
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _welcome(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.wb_sunny_outlined,
            size: 42,
            color: colors.onPrimaryContainer,
          ),
          const SizedBox(height: 28),
          Text(
            'Small steps.\nPossibility everywhere.',
            style: TextStyle(
              color: colors.onPrimaryContainer,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Your app starts here. Change the look, add your features, '
            'and turn this starting point into something of your own.',
            style: TextStyle(color: colors.onPrimaryContainer, height: 1.6),
          ),
        ],
      ),
    );
  }
}
