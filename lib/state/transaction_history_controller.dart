import 'package:flutter/foundation.dart';

import '../domain/transaction.dart';

class TransactionHistoryController extends ChangeNotifier {
  TransactionHistoryController(this._repository) {
    loadFirstPage();
  }

  final TransactionRepository _repository;
  final List<Transaction> _items = [];
  int _generation = 0;
  String? _cursor;
  TransactionStatus? _filter;
  bool _initialLoading = true;
  bool _refreshing = false;
  bool _loadingMore = false;
  bool _disposed = false;
  Object? _firstPageError;
  Object? _nextPageError;

  List<Transaction> get items => List.unmodifiable(_items);
  TransactionStatus? get filter => _filter;
  bool get initialLoading => _initialLoading;
  bool get refreshing => _refreshing;
  bool get loadingMore => _loadingMore;
  Object? get firstPageError => _firstPageError;
  Object? get nextPageError => _nextPageError;
  bool get hasMore => _cursor != null;

  Future<void> selectFilter(TransactionStatus? status) async {
    if (_filter == status) return;
    _filter = status;
    _items.clear();
    await loadFirstPage();
  }

  Future<void> loadFirstPage({bool refresh = false}) async {
    final generation = ++_generation;
    _initialLoading = _items.isEmpty && !refresh;
    _refreshing = refresh;
    _loadingMore = false;
    _firstPageError = null;
    _nextPageError = null;
    _cursor = null;
    notifyListeners();
    try {
      final page = await _repository.fetchTransactions(status: _filter);
      if (_disposed || generation != _generation) return;
      _items
        ..clear()
        ..addAll(page.transactions);
      _cursor = page.nextCursor;
    } catch (error) {
      if (_disposed || generation != _generation) return;
      _firstPageError = error;
    } finally {
      if (!_disposed && generation == _generation) {
        _initialLoading = false;
        _refreshing = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadNextPage() async {
    final cursor = _cursor;
    if (cursor == null || _loadingMore || _initialLoading || _refreshing) return;
    final generation = _generation;
    _loadingMore = true;
    _nextPageError = null;
    notifyListeners();
    try {
      final page = await _repository.fetchTransactions(cursor: cursor, status: _filter);
      if (_disposed || generation != _generation) return;
      final seen = _items.map((item) => item.id).toSet();
      _items.addAll(page.transactions.where((item) => seen.add(item.id)));
      _cursor = page.nextCursor;
    } catch (error) {
      if (_disposed || generation != _generation) return;
      _nextPageError = error;
    } finally {
      if (!_disposed && generation == _generation) {
        _loadingMore = false;
        notifyListeners();
      }
    }
  }

  Future<void> retryFirstPage() => loadFirstPage();
  Future<void> retryNextPage() => loadNextPage();

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
