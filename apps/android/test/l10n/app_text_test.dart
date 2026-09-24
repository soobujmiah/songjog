import 'package:flutter_test/flutter_test.dart';
import 'package:songjog/application/sale/sale_service.dart';
import 'package:songjog/l10n/app_text.dart';

void main() {
  group('AppText script purity', () {
    test('Bangla mode contains no Latin letters in UI copy', () {
      final banglaValues = AppText.values[AppLocale.bangla]!;
      final latinRegex = RegExp(r'[A-Za-z]');
      final placeholderRegex = RegExp(r'\{[^}]+\}');
      for (final entry in banglaValues.entries) {
        final cleaned = entry.value.replaceAll(placeholderRegex, '');
        if (latinRegex.hasMatch(cleaned)) {
          fail(
            'Bangla key "${entry.key}" contains Latin letters: "${entry.value}" (cleaned: "$cleaned")',
          );
        }
      }
    });

    test('English mode contains no Bengali script', () {
      final englishValues = AppText.values[AppLocale.english]!;
      final bengaliRegex = RegExp(r'[\u0980-\u09FF]');
      for (final entry in englishValues.entries) {
        if (bengaliRegex.hasMatch(entry.value)) {
          fail(
            'English key "${entry.key}" contains Bengali script: "${entry.value}"',
          );
        }
      }
    });

    test('All keys present in both locales', () {
      final banglaKeys = AppText.values[AppLocale.bangla]!.keys.toSet();
      final englishKeys = AppText.values[AppLocale.english]!.keys.toSet();
      expect(banglaKeys, englishKeys);
    });

    test('New keys for returnable and language exist', () {
      expect(AppText.get(AppLocale.bangla, 'returnable'), 'ফেরত');
      expect(AppText.get(AppLocale.english, 'returnable'), 'Change');
      expect(AppText.get(AppLocale.bangla, 'change_due'), 'ফেরত দিতে হবে');
      expect(AppText.get(AppLocale.english, 'change_due'), 'Change due');
      expect(AppText.get(AppLocale.bangla, 'language'), 'ভাষা');
      expect(AppText.get(AppLocale.english, 'language'), 'Language');
      expect(AppText.get(AppLocale.bangla, 'language_bangla'), 'বাংলা');
      expect(AppText.get(AppLocale.bangla, 'language_english'), 'ইংরেজি');
      expect(AppText.get(AppLocale.english, 'language_bangla'), 'Bangla');
      expect(AppText.get(AppLocale.english, 'language_english'), 'English');
    });
  });

  group('Money formatting with locale', () {
    test('minorToTaka formats correctly', () {
      expect(minorToTaka(85000), '850');
      expect(minorToTaka(350), '3.50');
    });

    test('toBanglaDigits converts correctly', () {
      expect(toBanglaDigits('850'), '৮৫০');
      expect(toBanglaDigits('3.50'), '৩.৫০');
      expect(toBanglaDigits('BDT 850'), 'BDT ৮৫০');
    });

    test('Bangla money uses Bangla numerals and ৳', () {
      String money(int minor, AppLocale locale) {
        final taka = minorToTaka(minor);
        final display = locale == AppLocale.bangla
            ? toBanglaDigits(taka)
            : taka;
        return locale == AppLocale.bangla ? '৳$display' : 'BDT $display';
      }

      expect(money(85000, AppLocale.bangla), '৳৮৫০');
      expect(money(5000, AppLocale.bangla), '৳৫০');
      expect(money(0, AppLocale.bangla), '৳০');
      expect(money(85000, AppLocale.english), 'BDT 850');
    });

    test('English money uses Latin digits and BDT', () {
      String money(int minor, AppLocale locale) {
        final taka = minorToTaka(minor);
        final display = locale == AppLocale.bangla
            ? toBanglaDigits(taka)
            : taka;
        return locale == AppLocale.bangla ? '৳$display' : 'BDT $display';
      }

      expect(money(85000, AppLocale.english), contains('BDT'));
      expect(money(85000, AppLocale.english), contains('850'));
      expect(money(85000, AppLocale.english), isNot(contains('৮৫০')));
    });

    test('calculateReturnable works for normal, exact, overpayment', () {
      expect(calculateReturnable(30000, 85000), 0);
      expect(calculateReturnable(85000, 85000), 0);
      expect(calculateReturnable(90000, 85000), 5000);
      expect(calculateReturnable(100000, 85000), 15000);
    });
  });

  group('New v0.2 keys', () {
    test('dashboard and action bar keys', () {
      expect(AppText.get(AppLocale.bangla, 'dashboard_sales_today'), isNotEmpty);
      expect(AppText.get(AppLocale.english, 'dashboard_sales_today'), "Today's sales");
      expect(AppText.get(AppLocale.bangla, 'dashboard_expenses_today'), isNotEmpty);
      expect(AppText.get(AppLocale.english, 'dashboard_expenses_today'), "Today's expenses");
      expect(AppText.get(AppLocale.bangla, 'dashboard_profit'), isNotEmpty);
      expect(AppText.get(AppLocale.english, 'dashboard_profit'), 'Net profit');
      expect(AppText.get(AppLocale.bangla, 'dashboard_outstanding_dues'), isNotEmpty);
      expect(AppText.get(AppLocale.english, 'dashboard_outstanding_dues'), 'Outstanding dues');
      expect(AppText.get(AppLocale.bangla, 'no_financial_data'), isNotEmpty);
      expect(AppText.get(AppLocale.english, 'no_financial_data'), 'No data');
      expect(AppText.get(AppLocale.bangla, 'new_expense'), isNotEmpty);
      expect(AppText.get(AppLocale.english, 'new_expense'), 'New expense');
      expect(AppText.get(AppLocale.bangla, 'new_purchase'), isNotEmpty);
      expect(AppText.get(AppLocale.english, 'new_purchase'), 'New purchase');
    });

    test('customer and product keys', () {
      expect(AppText.get(AppLocale.bangla, 'customers'), isNotEmpty);
      expect(AppText.get(AppLocale.english, 'customers'), 'Customers');
      expect(AppText.get(AppLocale.bangla, 'products'), isNotEmpty);
      expect(AppText.get(AppLocale.english, 'products'), 'Products');
      expect(AppText.get(AppLocale.bangla, 'new_customer'), isNotEmpty);
      expect(AppText.get(AppLocale.english, 'new_customer'), 'New customer');
      expect(AppText.get(AppLocale.bangla, 'new_product'), isNotEmpty);
      expect(AppText.get(AppLocale.english, 'new_product'), 'New product');
      expect(AppText.get(AppLocale.bangla, 'no_customers'), isNotEmpty);
      expect(AppText.get(AppLocale.english, 'no_customers'), 'No customers yet');
      expect(AppText.get(AppLocale.bangla, 'no_products'), isNotEmpty);
      expect(AppText.get(AppLocale.english, 'no_products'), 'No products yet');
      expect(AppText.get(AppLocale.bangla, 'no_customer_transactions'), isNotEmpty);
      expect(AppText.get(AppLocale.english, 'no_customer_transactions'), 'No transactions yet');
    });

    test('receipt share keys', () {
      expect(AppText.get(AppLocale.bangla, 'share_receipt'), isNotEmpty);
      expect(AppText.get(AppLocale.english, 'share_receipt'), 'Share receipt');
      expect(AppText.get(AppLocale.bangla, 'receipt_header'), isNotEmpty);
      expect(AppText.get(AppLocale.english, 'receipt_header'), 'Receipt');
    });
  });
}
