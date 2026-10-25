# BePay Transaction History

A standalone Flutter take-home project for a transaction history screen. It runs offline with deterministic local data and needs no account, credentials, backend, or network access at runtime.

## Assignment scope

This project implements the required transaction history flow:

- Displays merchant, local date/time, amount/currency, and transaction status.
- Supports **All**, **Completed**, **Pending**, and **Failed** filters.
- Uses a page size of 10 and loads additional rows as the list approaches its end.
- Supports pull-to-refresh and a refresh button. Refresh requests the first page using the active filter and replaces the previous result on success.
- Shows distinct initial-loading, empty, first-page error, refresh error, and next-page error states. Retry actions are provided for errors; a next-page failure keeps existing rows visible.
- Prevents duplicate next-page requests and duplicate transaction rows. A newer filter or refresh request invalidates older responses. Async completions after disposal are ignored.
- Includes deterministic automated tests for the data/state behavior and key screen interactions.

The UI uses a dark navy Material 3 theme with status colors and labels, merchant icons, accessible control tooltips, and scrollable filters.

## Toolchain

- Flutter **3.44.6 stable**
- Dart **3.12.2**
- Flutter SDK constraint in `pubspec.yaml`: Dart `>=3.3.0 <4.0.0`
- Runtime dependencies: Flutter SDK only. `flutter_lints` is used for development analysis.

The Flutter/Dart versions above are the versions available in the implementation environment. Check `flutter --version` if you use another SDK.

## Project layout

```text
lib/
  main.dart                              App setup and dependency wiring
  domain/transaction.dart                Transaction models and repository contract
  data/fake_transaction_repository.dart  Deterministic paginated local data source
  state/transaction_history_controller.dart
                                          Loading, filtering, pagination, and error state
  ui/transaction_history_screen.dart     Screen, transaction rows, and amount formatting
test/
  transaction_history_test.dart          State, repository, formatting, and interaction tests
  widget_test.dart                       App smoke test
```

Android and iOS project scaffolding is included. Android can be run from Windows with an Android emulator/device. Building or launching an iOS simulator requires macOS with Xcode.

## Architecture and design choices

The code is split into four small layers:

1. **Domain** — `Transaction`, `TransactionPage`, `TransactionStatus`, and the `TransactionRepository` interface. Transaction fields are final; money is stored as integer minor units, and timestamps are UTC.
2. **Data** — `FakeTransactionRepository` implements the repository interface, so the controller can be tested with a controlled fake or replaced with a real implementation later.
3. **State** — `TransactionHistoryController` uses Flutter's `ChangeNotifier`. This keeps the assignment dependency-light while centralizing request state and making async transitions directly testable.
4. **UI** — `TransactionHistoryScreen` renders controller state and sends filter, refresh, retry, and scroll events to the controller. It owns and disposes its scroll controller and injected history controller.

### Request consistency

- Every first-page request increments a generation number. Filter changes and refreshes therefore make earlier responses stale; only the current generation can update state.
- A next-page request is ignored while another next-page request is active, while a first-page request is active, or when there is no next cursor.
- Refresh retains the currently displayed rows while the request is pending, then replaces them when successful. If refresh fails, the rows remain and a refresh error with Retry is shown.
- Filter changes clear the old filtered rows, reset the cursor, and request page one for the new selection.
- Pagination adds only IDs that are not already in the loaded list.
- The controller checks disposal before processing results or notifying listeners.

## Fake data and pagination

The fake repository creates **36 deterministic transactions**: 12 per status, using both INR and USD. Sample timestamps are generated in UTC at fixed nine-hour intervals from a fixed base date. Results are sorted newest first, then by ID for a stable tie-break. The selected status is applied to the full data set before pagination. The page size is 10; cursors are string-encoded offsets, and `nextCursor` is null at the end.

The default artificial request delay is 500 ms. Tests set it to `Duration.zero` or use a controlled repository so they do not depend on wall-clock delays.

### Reproduce request failures in the app

Failures are deterministic and configured by one-based request number through `failOnCalls`. To try a scenario, temporarily edit the repository wiring in `lib/main.dart` from:

```dart
TransactionHistoryController(FakeTransactionRepository())
```

to one of these examples:

```dart
// Fail initial load (request 1); tap “Try again” to recover on request 2.
TransactionHistoryController(
  FakeTransactionRepository(failOnCalls: const {1}),
)

// Load the first page, then fail the next request (request 2).
// Scroll near the bottom and tap Retry; request 3 succeeds.
TransactionHistoryController(
  FakeTransactionRepository(failOnCalls: const {2}),
)
```

To see a refresh error, use `{2}`, let the first page load, then refresh before scrolling far enough to request another page. The error is shown while the existing rows remain. Remove `failOnCalls` (or restore the original constructor) for the normal demo. Request numbering counts all calls made by that repository instance, including retries, filters, and refreshes.

## Run the app

From the project root:
