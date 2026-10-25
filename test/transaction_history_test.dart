import 'dart:async';

import 'package:bepay_transaction_history/data/fake_transaction_repository.dart';
import 'package:bepay_transaction_history/domain/transaction.dart';
import 'package:bepay_transaction_history/state/transaction_history_controller.dart';
import 'package:bepay_transaction_history/ui/transaction_history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads pages and stops at the end', () async {
    final repository = FakeTransactionRepository(delay: Duration.zero);
    final controller = TransactionHistoryController(repository);
    await Future<void>.delayed(Duration.zero);
    expect(controller.items, hasLength(10));
    await controller.loadNextPage();
    await controller.loadNextPage();
    await controller.loadNextPage();
    expect(controller.items, hasLength(36));
    expect(controller.hasMore, isFalse);
    expect(controller.items.map((item) => item.id).toSet(), hasLength(36));
    controller.dispose();
  });

  test('next page failure retry preserves loaded rows without duplicates', () async {
    final repository = FakeTransactionRepository(
      delay: Duration.zero,
      failOnCalls: const {2},
    );
    final controller = TransactionHistoryController(repository);
    await Future<void>.delayed(Duration.zero);
    final firstPageIds = controller.items.map((item) => item.id).toList();
    await controller.loadNextPage();
    expect(controller.nextPageError, isNotNull);
    expect(controller.items.map((item) => item.id), firstPageIds);
    await controller.retryNextPage();
    expect(controller.items, hasLength(20));
    expect(controller.items.map((item) => item.id).toSet(), hasLength(20));
    controller.dispose();
  });

  test('initial page failure can be retried successfully', () async {
    final repository = FakeTransactionRepository(
      delay: Duration.zero,
      failOnCalls: const {1},
    );
    final controller = TransactionHistoryController(repository);
    await Future<void>.delayed(Duration.zero);
    expect(controller.items, isEmpty);
    expect(controller.firstPageError, isNotNull);
    await controller.retryFirstPage();
    expect(controller.firstPageError, isNull);
    expect(controller.items, hasLength(10));
    controller.dispose();
  });

  test('filter is applied before pagination and preserves stable newest-first order', () async {
    final repository = FakeTransactionRepository(delay: Duration.zero);
    final controller = TransactionHistoryController(repository);
    await Future<void>.delayed(Duration.zero);
    await controller.selectFilter(TransactionStatus.failed);
    expect(controller.items, hasLength(10));
    expect(controller.items.every((item) => item.status == TransactionStatus.failed), isTrue);
    await controller.loadNextPage();
    await controller.loadNextPage();
    expect(controller.items, hasLength(12));
    expect(controller.hasMore, isFalse);
    for (var i = 1; i < controller.items.length; i++) {
      expect(controller.items[i - 1].createdAt.isAfter(controller.items[i].createdAt), isTrue);
    }
    controller.dispose();
  });

  test('refresh replaces rows and keeps the selected filter', () async {
    final repository = _ControlledRepository();
    final controller = TransactionHistoryController(repository);
    final filterLoad = controller.selectFilter(TransactionStatus.pending);
    repository.completers[1].complete(TransactionPage(
      transactions: [_tx('before-refresh', TransactionStatus.pending)],
      nextCursor: '10',
    ));
    await filterLoad;

    final refresh = controller.loadFirstPage(refresh: true);
    expect(controller.items.single.id, 'before-refresh');
    repository.completers[2].complete(TransactionPage(
      transactions: [_tx('after-refresh', TransactionStatus.pending)],
    ));
    await refresh;

    expect(controller.filter, TransactionStatus.pending);
    expect(controller.items.map((item) => item.id), ['after-refresh']);
    expect(repository.statuses[2], TransactionStatus.pending);
    controller.dispose();
  });

  test('repeated pagination calls issue one request and append one page', () async {
    final repository = _ControlledRepository();
    final controller = TransactionHistoryController(repository);
    repository.completers[0].complete(TransactionPage(
      transactions: [_tx('first', TransactionStatus.completed)],
      nextCursor: '10',
    ));
    await repository.requests[0];

    final firstLoad = controller.loadNextPage();
    final duplicateLoad = controller.loadNextPage();
    expect(repository.completers, hasLength(2));
    repository.completers[1].complete(TransactionPage(
      transactions: [_tx('second', TransactionStatus.completed)],
    ));
    await Future.wait([firstLoad, duplicateLoad]);
    expect(controller.items.map((item) => item.id), ['first', 'second']);
    controller.dispose();
  });

  test('refresh supersedes an in-flight pagination response', () async {
    final repository = _ControlledRepository();
    final controller = TransactionHistoryController(repository);
    repository.completers[0].complete(TransactionPage(
      transactions: [_tx('old-first', TransactionStatus.completed)],
      nextCursor: '10',
    ));
    await repository.requests[0];

    final pageLoad = controller.loadNextPage();
    final refresh = controller.loadFirstPage(refresh: true);
    repository.completers[2].complete(TransactionPage(
      transactions: [_tx('fresh-first', TransactionStatus.completed)],
      nextCursor: '10',
    ));
    await refresh;
    repository.completers[1].complete(TransactionPage(
      transactions: [_tx('stale-next', TransactionStatus.completed)],
    ));
    await pageLoad;

    expect(controller.items.map((item) => item.id), ['fresh-first']);
    expect(controller.hasMore, isTrue);
    controller.dispose();
  });

  test('completing a request after disposal does not notify listeners', () async {
    final repository = _ControlledRepository();
    final controller = TransactionHistoryController(repository);
    var notifications = 0;
    controller.addListener(() => notifications++);
    controller.dispose();
    repository.completers[0].complete(TransactionPage(
      transactions: [_tx('late-result', TransactionStatus.completed)],
    ));
    await repository.requests[0];
    expect(notifications, 0);
  });

  test('filter response wins over an older pending request', () async {
    final repository = _ControlledRepository();
    final controller = TransactionHistoryController(repository);
    final oldRequest = repository.requests[0];
    final filterRequest = controller.selectFilter(TransactionStatus.failed);
    repository.completers[1].complete(TransactionPage(
      transactions: [Transaction(
        id: 'new', merchantName: 'Latest', amountMinor: 100, currencyCode: 'INR',
        status: TransactionStatus.failed, createdAt: DateTime.utc(2026),
      )],
    ));
    await filterRequest;
    repository.completers[0].complete(TransactionPage(
      transactions: [Transaction(
        id: 'old', merchantName: 'Stale', amountMinor: 200, currencyCode: 'USD',
        status: TransactionStatus.completed, createdAt: DateTime.utc(2025),
      )],
    ));
    await oldRequest;
    expect(controller.items.single.id, 'new');
    controller.dispose();
  });

  testWidgets('applying a filter updates the visible transactions', (tester) async {
    final controller = TransactionHistoryController(
      FakeTransactionRepository(delay: Duration.zero),
    );
    await tester.pumpWidget(MaterialApp(home: TransactionHistoryScreen(controller: controller)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Failed'));
    await tester.pumpAndSettle();
    expect(controller.filter, TransactionStatus.failed);
    expect(controller.items, isNotEmpty);
    expect(controller.items.every((item) => item.status == TransactionStatus.failed), isTrue);
  });

  testWidgets('first-page error offers a working retry action', (tester) async {
    final controller = TransactionHistoryController(
      FakeTransactionRepository(delay: Duration.zero, failOnCalls: const {1}),
    );
    await tester.pumpWidget(MaterialApp(home: TransactionHistoryScreen(controller: controller)));
    await tester.pumpAndSettle();
    expect(find.text('Couldn’t load transactions'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(controller.firstPageError, isNull);
    expect(controller.items, hasLength(10));
  });

  test('formats INR and USD without floating point amounts', () {
    expect(formatAmount(129900, 'INR'), '₹1,299.00');
    expect(formatAmount(123456789, 'USD'), r'$1,234,567.89');
  });
}

class _ControlledRepository implements TransactionRepository {
  final List<Completer<TransactionPage>> completers = [];
  final List<Future<TransactionPage>> requests = [];
  final List<TransactionStatus?> statuses = [];
  final List<String?> cursors = [];

  @override
  Future<TransactionPage> fetchTransactions({String? cursor, TransactionStatus? status}) {
    cursors.add(cursor);
    statuses.add(status);
    final completer = Completer<TransactionPage>();
    completers.add(completer);
    requests.add(completer.future);
    return requests.last;
  }
}

Transaction _tx(String id, TransactionStatus status) => Transaction(
      id: id,
      merchantName: 'Test merchant',
      amountMinor: 129900,
      currencyCode: 'INR',
      status: status,
      createdAt: DateTime.utc(2026, 10, 25),
    );
