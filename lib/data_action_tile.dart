import 'package:flutter/material.dart';

typedef DataAction = (IconData icon, String label, VoidCallback run);

class DataActionTile extends StatelessWidget {
  const DataActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.actions,
    this.busy = false,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final List<DataAction> actions;
  final bool busy;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? Theme.of(context).colorScheme.error : null;
    return ListTile(
      leading: busy
          ? const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => showModalBottomSheet(
        context: context,
        useRootNavigator: true,
        builder: (context) => SafeArea(
          child: Wrap(
            children: [
              for (final (icon, label, run) in actions)
                ListTile(
                  leading: Icon(icon),
                  title: Text(label),
                  onTap: () {
                    Navigator.pop(context);
                    run();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
