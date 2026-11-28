import 'package:flex/responsive.dart';
import 'package:flex/support_email.dart';
import 'package:flex/delete_records_button.dart';
import 'package:flex/export_data.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';

class FailedMigrationsPage extends StatelessWidget {
  final Object error;

  const FailedMigrationsPage({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(context.l10n.failedMigrations),
        leading: const Icon(Icons.error),
      ),
      body: ResponsiveContent(
        maxWidth: 800,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(pagePadding),
          child: Column(
            children: [
              ListTile(
                title: Text(context.l10n.databaseMigrationFailureDescription),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: SingleChildScrollView(
                  child: ListTile(
                    dense: true,
                    title: Text(context.l10n.errorMessageLabel),
                    subtitle: Text(error.toString()),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const ExportData(),
              DeleteRecordsButton(ctx: context),
              ListTile(
                onTap: () => launchUrlString(
                  'https://github.com/brandonp2412/Flex/releases',
                  mode: LaunchMode.externalApplication,
                ),
                title: Text(context.l10n.viewReleases),
                leading: const Icon(Icons.open_in_new),
                trailing: const Icon(Icons.chevron_right_rounded),
              ),
              ListTile(
                onTap: () async {
                  final url = buildSupportEmail(
                    subject: context.l10n.failedMigrations,
                    body: error.toString(),
                  ).toString();

                  await launchUrlString(url);
                },
                title: Text(context.l10n.emailDeveloper),
                leading: const Icon(Icons.email_outlined),
                trailing: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
