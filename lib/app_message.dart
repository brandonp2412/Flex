import 'package:flex/main.dart';
import 'package:flutter/material.dart';

void showAppMessage(String message) => messengerKey.currentState!.showSnackBar(
  SnackBar(
    content: Text(message),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    duration: const Duration(seconds: 4),
    persist: false,
  ),
);
