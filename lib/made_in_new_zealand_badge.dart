import 'package:flutter/material.dart';

class MadeInNewZealandBadge extends StatelessWidget {
  const MadeInNewZealandBadge({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Made in New Zealand',
    image: true,
    child: Image.asset(
      'assets/made_in_new_zealand.png',
      key: const Key('made-in-new-zealand-branding'),
      width: 200,
      height: 80,
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
    ),
  );
}
