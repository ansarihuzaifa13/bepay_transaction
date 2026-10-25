enum TransactionStatus { completed, pending, failed }

class Transaction {
  const Transaction({
    required this.id,
    required this.merchantName,
    required this.amountMinor,
    required this.currencyCode,
    required this.status,
    required this.createdAt,
    this.reference,
  });

  final String id;
  final String merchantName;
  final int amountMinor;
  final String currencyCode;
  final TransactionStatus status;
  final DateTime createdAt;
  final String? reference;
}

class TransactionPage {
  const TransactionPage({required this.transactions, this.nextCursor});

  final List<Transaction> transactions;
  final String? nextCursor;
}

abstract interface class TransactionRepository {
  Future<TransactionPage> fetchTransactions({
    String? cursor,
    TransactionStatus? status,
  });
}
