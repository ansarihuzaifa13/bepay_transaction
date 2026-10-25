import '../domain/transaction.dart';

class FakeTransactionRepository implements TransactionRepository {
  FakeTransactionRepository({
    this.delay = const Duration(milliseconds: 500),
    this.failOnCalls = const {},
  }) : _transactions = _buildTransactions();

  final Duration delay;
  final Set<int> failOnCalls;
  final List<Transaction> _transactions;
  int _callCount = 0;
  static const int pageSize = 10;

  int get callCount => _callCount;

  @override
  Future<TransactionPage> fetchTransactions({
    String? cursor,
    TransactionStatus? status,
  }) async {
    final call = ++_callCount;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (failOnCalls.contains(call)) {
      throw TransactionFetchException('Simulated request failure (request $call).');
    }

    final filtered = _transactions
        .where((transaction) => status == null || transaction.status == status)
        .toList()
      ..sort((a, b) {
        final byDate = b.createdAt.compareTo(a.createdAt);
        return byDate != 0 ? byDate : a.id.compareTo(b.id);
      });

    final start = cursor == null ? 0 : int.tryParse(cursor);
    if (start == null || start < 0 || start > filtered.length) {
      throw const FormatException('Invalid transaction cursor.');
    }
    final end = (start + pageSize).clamp(0, filtered.length);
    return TransactionPage(
      transactions: List.unmodifiable(filtered.sublist(start, end)),
      nextCursor: end < filtered.length ? '$end' : null,
    );
  }

  static List<Transaction> _buildTransactions() {
    const merchants = [
      'Blue Tokai Coffee', 'Amazon', 'Myntra', 'Uber', 'Swiggy',
      'Apple Services', 'BookMyShow', 'Whole Foods', 'Spotify', 'Air India',
    ];
    final base = DateTime.utc(2026, 10, 25, 12);
    return List.generate(36, (index) {
      final status = TransactionStatus.values[index % 3];
      return Transaction(
        id: 'txn-${(index + 1).toString().padLeft(3, '0')}',
        merchantName: merchants[index % merchants.length],
        amountMinor: 129900 + index * 17525,
        currencyCode: index % 2 == 0 ? 'INR' : 'USD',
        status: status,
        createdAt: base.subtract(Duration(hours: index * 9)).toUtc(),
        reference: index.isEven ? 'BP${(840000 + index)}' : null,
      );
    });
  }
}

class TransactionFetchException implements Exception {
  const TransactionFetchException(this.message);
  final String message;

  @override
  String toString() => message;
}
