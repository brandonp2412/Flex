import 'package:flex/database/categories.dart';
import 'package:flex/database/database.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/platform_page_route.dart';
import 'package:flex/settings/category_management_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class WorkoutCategoryField extends StatelessWidget {
  const WorkoutCategoryField({
    super.key,
    required this.initial,
    required this.onChanged,
    this.hint,
    this.onController,
    this.keepHidden = false,
  });
  final String? initial;
  final String? hint;
  final ValueChanged<String?> onChanged;
  final ValueChanged<TextEditingController>? onController;
  final bool keepHidden;

  @override
  Widget build(BuildContext context) => Selector<Setting, bool>(
    selector: (context, settings) => settings.showCategories,
    builder: (context, show, child) {
      if (!show && !keepHidden) return const SizedBox();
      return Visibility(
        visible: show,
        child: StreamBuilder<List<String>>(
          stream: getCategoriesStream(),
          builder: (context, snapshot) => Autocomplete<String>(
            initialValue: TextEditingValue(text: initial ?? ''),
            optionsBuilder: (value) => (snapshot.data ?? []).where(
              (option) =>
                  option.toLowerCase().contains(value.text.toLowerCase()),
            ),
            onSelected: onChanged,
            fieldViewBuilder: (context, controller, focusNode, _) {
              onController?.call(controller);
              return TextFormField(
                controller: controller,
                focusNode: focusNode,
                decoration: InputDecoration(
                  labelText: context.l10n.categoryLabel,
                  hintText: hint,
                  helperText: context.l10n.categoryHelper,
                  suffixIcon: IconButton(
                    tooltip: context.l10n.manageCategories,
                    icon: const Icon(Icons.settings),
                    onPressed: () => Navigator.of(context).push(
                      FlexPageRoute(
                        builder: (_) => const CategoryManagementPage(),
                      ),
                    ),
                  ),
                ),
                onChanged: (value) => onChanged(value.isEmpty ? null : value),
              );
            },
          ),
        ),
      );
    },
  );
}
