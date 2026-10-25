import 'package:flutter/material.dart';

import 'data/fake_transaction_repository.dart';
import 'state/transaction_history_controller.dart';
import 'ui/transaction_history_screen.dart';

void main() {
  runApp(const BePayApp());
}

class BePayApp extends StatelessWidget {
  const BePayApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'BePay · Activity',
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF8EA9FF),
            brightness: Brightness.dark,
            surface: const Color(0xFF101827),
          ),
          scaffoldBackgroundColor: const Color(0xFF101827),
          cardTheme: const CardThemeData(
            elevation: 0,
            margin: EdgeInsets.zero,
            color: Color(0xFF182438),
          ),
        ),
        home: TransactionHistoryScreen(
          controller: TransactionHistoryController(FakeTransactionRepository()),
        ),
      );
}
