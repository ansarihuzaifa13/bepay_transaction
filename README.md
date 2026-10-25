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

```sh
flutter --version
flutter pub get
flutter devices
flutter run
```

If more than one device is available, choose one explicitly:

```sh
flutter run -d <device-id>
```

Use an Android emulator or connected Android device on Windows. The simulator experience is the same for the assignment's history flow.

## Analyze and test

```sh
flutter analyze
flutter test
```

`transaction_history_test.dart` currently contains **12 focused tests** covering:

1. Initial page load, successive pages, deduplication, and reaching the end.
2. Next-page failure followed by retry, preserving existing rows without duplicates.
3. Initial-page failure followed by successful retry.
4. Filtering before pagination and newest-first ordering.
5. Refresh replacing the old result while retaining the selected filter.
6. Repeated pagination calls producing only one request and one append.
7. Refresh invalidating an in-flight pagination response.
8. A request completing after disposal without notifying listeners.
9. A filter response winning over an older pending request.
10. Widget interaction applying the Failed filter.
11. Widget initial-error state and its working Retry action.
12. INR and USD display formatting, including grouped digits and two decimal places.

The additional smoke test in `widget_test.dart` verifies that the BePay history screen opens, for **13 tests total** across the project.

**Verification note:** the implementation environment's Flutter CLI stalled without returning output when `flutter analyze` was attempted. Analyzer and test results have therefore not been confirmed here. Run both commands above before submission and report their actual results; do not describe them as passing unless they do.

## Amount and date display

Amounts remain integer minor units throughout data access and state management. Formatting happens only in the UI: INR uses `₹`, USD uses `$`, and both show two decimal places. UTC timestamps are converted with `toLocal()` before display. The formatter intentionally supports the assignment's sample currencies (INR and USD); it is not a general-purpose locale/currency formatter.

## Tradeoffs and possible follow-up work

- `ChangeNotifier` was chosen instead of adding BLoC or another package. It provides a small, explicit state boundary for this one-screen feature and is easy to inject in tests.
- The fake cursor is an offset for simplicity. A production API should use its opaque server cursor and define how snapshots behave if records change between requests.
- Number and date formatting are intentionally limited to the assignment's INR/USD examples and a compact local date label. Full locale-aware formatting would use locale data and currency rules.
- There is no persistence, search, transaction detail screen, backend integration, or live payment data. These were optional or outside the required standalone scope.
- The fake data and failure setup are for a reproducible demo, not production configuration.

## Submission details to fill in

- **Approximate time spent:** `[enter your actual total before submitting]` (the assignment asks candidates to stop at five hours and report unfinished work).
- **Outstanding verification:** run `flutter analyze` and `flutter test` with your installed SDK and update the verification note above with the actual outcomes.
#   b e p a y _ t r a n s a c t i o n  
 