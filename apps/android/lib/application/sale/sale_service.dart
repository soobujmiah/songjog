import '../../data/repositories/business_repository.dart';
import '../../domain/models/transaction.dart';
import '../../domain/services/diagnostic_collector.dart';

/// Exact BDT taka (string) to minor-unit (paisa, integer) conversion.
///
/// Persisted money is always integer minor units. UI input arrives as a plain
/// decimal string ("850", "3.50"); parsing is string/integer based so no
/// floating point ever touches money (see docs/FINANCIAL_MODEL.md §9).
///
/// Only non-negative amounts are supported here; sale entry does not accept
/// negatives. Accepts both Latin and Bangla digits.
int takaToMinor(String raw) {
  final latinText = toLatinDigits(raw.trim());
  final match = RegExp(r'^(\d{1,12})(?:\.(\d{1,2}))?$').firstMatch(latinText);
  if (match == null) {
    throw FormatException('Invalid amount: $raw');
  }
  final whole = int.parse(match.group(1)!);
  final frac = match.group(2) == null
      ? 0
      : int.parse(match.group(2)!.padRight(2, '0'));
  return whole * 100 + frac;
}

/// Deterministic display for a minor-unit value: integer part always,
/// fractional part trimmed (85000 → "850", 350 → "3.50", 5 → "0.05").
String minorToTaka(int minor) {
  final negative = minor < 0;
  final abs = negative ? -minor : minor;
  final whole = abs ~/ 100;
  final frac = abs % 100;
  final text = frac == 0
      ? '$whole'
      : (frac < 10 ? '$whole.0$frac' : '$whole.$frac');
  return negative ? '-$text' : text;
}

/// Converts Latin digits 0-9 in [input] to Bangla digits ০-৯.
/// Keeps non-digit characters (dot, minus) unchanged.
String toBanglaDigits(String input) {
  const latin = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  const bangla = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
  var result = input;
  for (var i = 0; i < 10; i++) {
    result = result.replaceAll(latin[i], bangla[i]);
  }
  return result;
}

/// Converts Bangla digits ০-৯ in [input] to Latin digits 0-9.
/// Keeps other characters unchanged. Used for parsing user input that may contain Bangla numerals.
String toLatinDigits(String input) {
  const latin = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  const bangla = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
  var result = input;
  for (var i = 0; i < 10; i++) {
    result = result.replaceAll(bangla[i], latin[i]);
  }
  return result;
}

/// Calculates returnable/change money when entered paid exceeds total.
/// Returns 0 when paid <= total. Exact int math, never negative.
int calculateReturnable(int enteredPaidMinor, int totalMinor) =>
    enteredPaidMinor > totalMinor ? enteredPaidMinor - totalMinor : 0;

/// Payment status derived from total and received amount.
PaymentStatus derivePaymentStatus({
  required int totalMinor,
  required int paidMinor,
}) {
  if (totalMinor <= 0 || paidMinor <= 0) return PaymentStatus.unpaid;
  if (paidMinor >= totalMinor) return PaymentStatus.paid;
  return PaymentStatus.partial;
}

/// Clamps a received amount into `[0, total]` (exact int math): a payment
/// can never silently exceed the applicable balance.
int clampPaid(int paidMinor, int totalMinor) =>
    paidMinor < 0 ? 0 : (paidMinor > totalMinor ? totalMinor : paidMinor);

/// Builds and persists sale transactions from completed entry lines.
class SaleEntryService {
  const SaleEntryService(this._repository, this._diagnostics);

  final BusinessRepository _repository;
  final DiagnosticCollector? _diagnostics;

  /// Persists a transaction (sale, expense, or purchase). The received amount
  /// is clamped into `[0, total]` so a payment can never silently exceed the
  /// applicable balance.
  Future<TransactionRecord> saveSale({
    required List<({String description, double quantity, int priceMinor, int? costMinor})> lines,
    int paidMinor = 0,
    PaymentMethod? paymentMethod,
    TransactionType type = TransactionType.sale,
  }) async {
    if (lines.isEmpty) {
      throw ArgumentError('A transaction needs at least one line.');
    }
    final now = DateTime.now();
    final recordLines = [
      for (var i = 0; i < lines.length; i++)
        TransactionLine(
          id: '${now.microsecondsSinceEpoch}-$i',
          description: lines[i].description,
          quantity: lines[i].quantity,
          sellingPriceMinor: lines[i].priceMinor,
          actualCostMinor: lines[i].costMinor,
        ),
    ];
    final total = recordLines.fold<int>(
      0,
      (sum, line) => sum + line.lineTotalMinor,
    );
    final clamped = type == TransactionType.expense ? 0 : clampPaid(paidMinor, total);
    final record = TransactionRecord(
      id: now.microsecondsSinceEpoch.toString(),
      type: type,
      createdAt: now,
      lines: recordLines,
      paymentMethod: paymentMethod,
      paidMinor: clamped,
      paymentStatus: type == TransactionType.expense
          ? PaymentStatus.paid
          : derivePaymentStatus(totalMinor: total, paidMinor: clamped),
    );
    try {
      await _repository.saveTransaction(record);
      _diagnostics?.record(
        level: 'info',
        category: 'transaction',
        operation: 'transaction_save',
        message: '${type.name} saved',
        details: {
          'lines': record.lines.length,
          'total_minor': total,
          'paid_minor': clamped,
          'payment_status': record.paymentStatus.name,
        },
      );
    } catch (error, stack) {
      _diagnostics?.record(
        level: 'error',
        category: 'transaction',
        operation: 'transaction_save',
        message: '${type.name} save failed',
        error: error.toString(),
        stackTrace: stack.toString(),
      );
      rethrow;
    }
    return record;
  }
}
