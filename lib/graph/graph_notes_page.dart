import 'dart:async';

import 'package:flex/l10n/l10n.dart';
import 'package:flutter/material.dart';

class GraphNotesPage extends StatefulWidget {
  final String initialNotes;
  final ValueChanged<String> onSave;

  const GraphNotesPage({
    super.key,
    required this.initialNotes,
    required this.onSave,
  });

  @override
  State<GraphNotesPage> createState() => _GraphNotesPageState();
}

class _GraphNotesPageState extends State<GraphNotesPage> {
  final _debounceDuration = const Duration(milliseconds: 600);
  late final _controller = TextEditingController(text: widget.initialNotes);
  Timer? _debounce;

  void _edit(String text) {
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, () => widget.onSave(text));
  }

  @override
  void dispose() {
    if (_debounce?.isActive == true) {
      _debounce!.cancel();
      widget.onSave(_controller.text);
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.exerciseNotes),
        leading: IconButton(
          tooltip: context.l10n.actionBack,
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _controller,
            onChanged: _edit,
            autofocus: true,
            expands: true,
            maxLines: null,
            minLines: null,
            textAlignVertical: TextAlignVertical.top,
            keyboardType: TextInputType.multiline,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: context.l10n.notesForExercise,
            ),
          ),
        ),
      ),
    );
  }
}
