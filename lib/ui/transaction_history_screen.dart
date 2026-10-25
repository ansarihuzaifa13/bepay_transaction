import 'package:flutter/material.dart';

import '../domain/transaction.dart';
import '../state/transaction_history_controller.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key, required this.controller});
  final TransactionHistoryController controller;

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.extentAfter < 260) {
      widget.controller.loadNextPage();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: AnimatedBuilder(
            animation: widget.controller,
            builder: (context, _) => Column(
              children: [
                _header(context),
                _filters(),
                Expanded(child: _body(context)),
              ],
            ),
          ),
        ),
      );

  Widget _header(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF6385F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.account_balance_wallet_rounded,
                  color: Colors.white, size: 19, semanticLabel: 'BePay wallet'),
            ),
            const SizedBox(width: 9),
            const Text('bepay', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -.5)),
            const Spacer(),
            IconButton.filledTonal(
              tooltip: 'Refresh transactions',
              onPressed: () => widget.controller.loadFirstPage(refresh: true),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ]),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 126),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [Color(0xFF121B32), Color(0xFF1A3158), Color(0xFF244D70)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: const [BoxShadow(color: Color(0x33102038), blurRadius: 24, offset: Offset(0, 10))],
            ),
            child: Stack(children: [
              Positioned(right: -24, top: -62, child: _orb(176, const Color(0x22FFFFFF))),
              Positioned(right: 56, bottom: -106, child: _orb(170, const Color(0x1A9BE9FF))),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 17, 20, 16),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('YOUR MONEY, IN MOTION',
                        style: TextStyle(color: Color(0xFFBFD0FF), fontSize: 10, letterSpacing: 1.3, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    const Text('Everyday activity',
                        style: TextStyle(color: Colors.white, fontSize: 23, height: 1.08, fontWeight: FontWeight.w800, letterSpacing: -.4)),
                    const SizedBox(height: 6),
                    Text(widget.controller.initialLoading
                            ? 'Fetching your latest transactions'
                            : '${widget.controller.items.length} transactions shown',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFFD6E0FF), fontSize: 11)),
                  ])),
                  const SizedBox(width: 8),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0x28FFFFFF),
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(color: const Color(0x40FFFFFF)),
                    ),
                    child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 25),
                  ),
                ]),
              ),
            ]),
          ),
        ]),
      );

  Widget _orb(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );

  Widget _filters() {
    const filters = <String, TransactionStatus?>{
      'All': null,
      'Completed': TransactionStatus.completed,
      'Pending': TransactionStatus.pending,
      'Failed': TransactionStatus.failed,
    };
    return SizedBox(
      height: 56,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
        scrollDirection: Axis.horizontal,
        children: filters.entries.map((entry) {
          final selected = widget.controller.filter == entry.value;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(entry.key),
              selected: selected,
              onSelected: (_) => widget.controller.selectFilter(entry.value),
              showCheckmark: false,
              labelStyle: TextStyle(
                fontWeight: FontWeight.w600,
                color: selected ? const Color(0xFF101827) : const Color(0xFFD0D9E8),
              ),
              selectedColor: const Color(0xFF9CB2FF),
              backgroundColor: const Color(0xFF1A2639),
              side: BorderSide(color: selected ? const Color(0xFF9CB2FF) : const Color(0xFF2B3A50)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final controller = widget.controller;
    if (controller.initialLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.firstPageError != null && controller.items.isEmpty) {
      return _messageState(
        icon: Icons.cloud_off_outlined,
        title: 'Couldn’t load transactions',
        detail: 'Check back in a moment and try again.',
        action: 'Try again',
        onAction: controller.retryFirstPage,
      );
    }
    if (controller.items.isEmpty) {
      return _messageState(
        icon: Icons.receipt_long_outlined,
        title: 'No transactions yet',
        detail: 'Transactions matching this filter will show here.',
      );
    }
    return RefreshIndicator(
      onRefresh: () => controller.loadFirstPage(refresh: true),
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
        itemCount: controller.items.length +
            (controller.firstPageError != null ? 1 : 0) +
            (controller.loadingMore || controller.nextPageError != null ? 1 : 0),
        itemBuilder: (context, index) {
          if (controller.firstPageError != null && index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: ListTile(
                  leading: const Icon(Icons.cloud_off_outlined, semanticLabel: 'Refresh failed'),
                  title: const Text('Couldn’t refresh transactions'),
                  subtitle: const Text('Showing your previously loaded transactions.'),
                  trailing: TextButton(
                    onPressed: controller.retryFirstPage,
                    child: const Text('Retry'),
                  ),
                ),
              ),
            );
          }
          final transactionIndex = index - (controller.firstPageError != null ? 1 : 0);
          if (transactionIndex == controller.items.length) {
            if (controller.nextPageError != null) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  const Text('Couldn’t load more transactions.'),
                  TextButton.icon(
                    onPressed: controller.retryNextPage,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ]),
              );
            }
            return const Padding(
              padding: EdgeInsets.all(22),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _transactionTile(context, controller.items[transactionIndex]);
        },
      ),
    );
  }

  Widget _messageState({
    required IconData icon,
    required String title,
    required String detail,
    String? action,
    Future<void> Function()? onAction,
  }) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 48, color: const Color(0xFF9EACC1), semanticLabel: title),
            const SizedBox(height: 14),
            Text(title, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(detail, textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFA8B5C8))),
            if (action != null) ...[
              const SizedBox(height: 12),
              FilledButton(onPressed: onAction, child: Text(action)),
            ],
          ]),
        ),
      );

  Widget _transactionTile(BuildContext context, Transaction transaction) {
    final (color, icon, label) = switch (transaction.status) {
      TransactionStatus.completed => (const Color(0xFF5DDAA2), Icons.check_circle, 'Completed'),
      TransactionStatus.pending => (const Color(0xFFFFCC70), Icons.schedule, 'Pending'),
      TransactionStatus.failed => (const Color(0xFFFF858B), Icons.cancel, 'Failed'),
    };
    final merchantIcon = switch (transaction.merchantName) {
      'Blue Tokai Coffee' => Icons.coffee_rounded,
      'Amazon' || 'Myntra' => Icons.shopping_bag_rounded,
      'Uber' || 'Air India' => Icons.directions_rounded,
      'Swiggy' || 'Whole Foods' => Icons.restaurant_rounded,
      'Apple Services' => Icons.phone_iphone_rounded,
      'BookMyShow' => Icons.confirmation_number_rounded,
      'Spotify' => Icons.music_note_rounded,
      _ => Icons.storefront_rounded,
    };
    const merchantColor = Color(0xFF9CB2FF);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(19),
        side: const BorderSide(color: Color(0xFF26354B)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        child: Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: const Color(0xFF263653), borderRadius: BorderRadius.circular(15)),
            child: Icon(merchantIcon, color: merchantColor, semanticLabel: '${transaction.merchantName} transaction'),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(transaction.merchantName,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 5),
              Text(_dateLabel(transaction.createdAt.toLocal()),
                  style: const TextStyle(fontSize: 12, color: Color(0xFFA8B5C8))),
              const SizedBox(height: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: color.withValues(alpha: .09), borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, size: 12, color: color, semanticLabel: label),
                  const SizedBox(width: 4),
                  Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
                ]),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          Text(formatAmount(transaction.amountMinor, transaction.currencyCode),
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: -.3)),
        ]),
      ),
    );
  }

  String _dateLabel(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    return '${months[date.month - 1]} ${date.day}, ${date.year} · $hour:$minute ${date.hour >= 12 ? 'PM' : 'AM'}';
  }
}

String formatAmount(int amountMinor, String currencyCode) {
  final major = amountMinor ~/ 100;
  final fraction = (amountMinor % 100).toString().padLeft(2, '0');
  final formatted = _groupDigits(major.toString());
  return switch (currencyCode) {
    'INR' => '₹$formatted.$fraction',
    'USD' => '\$$formatted.$fraction',
    _ => '$currencyCode $formatted.$fraction',
  };
}

String _groupDigits(String digits) {
  if (digits.length <= 3) return digits;
  final lastThree = digits.substring(digits.length - 3);
  final prefix = digits.substring(0, digits.length - 3);
  final groups = <String>[];
  for (var end = prefix.length; end > 0; end -= 2) {
    final start = end - 2 < 0 ? 0 : end - 2;
    groups.insert(0, prefix.substring(start, end));
  }
  return '${groups.join(',')},$lastThree';
}
