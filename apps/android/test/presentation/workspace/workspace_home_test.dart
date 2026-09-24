import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songjog/app/app_services.dart';
import 'package:songjog/application/onboarding/onboarding_service.dart';
import 'package:songjog/data/export/share_service.dart';
import 'package:songjog/data/local/in_memory_store.dart';
import 'package:songjog/data/repositories/business_repository.dart';
import 'package:songjog/domain/models/business_profile.dart';
import 'package:songjog/domain/models/transaction.dart';
import 'package:songjog/domain/services/diagnostic_collector.dart';
import 'package:songjog/domain/services/diagnostic_report.dart';
import 'package:songjog/domain/services/export_payload.dart';
import 'package:songjog/domain/services/export_service_impl.dart';
import 'package:songjog/l10n/app_text.dart';
import 'package:songjog/presentation/sale/sale_entry_screen.dart';
import 'package:songjog/presentation/workspace/workspace_home_page.dart';

class _FakeExportAdapter implements ExportFileAdapter {
  @override
  Future<String> save(ExportPayload payload) async => 'memory:/unused';

  @override
  Future<void> share(ExportPayload payload) async {}
}

class _NoopShareService implements ShareService {
  @override
  Future<bool> shareFile({
    required String path,
    required String mimeType,
    String? title,
  }) async => true;
}

class _FixedReportSource implements DiagnosticReportSource {
  @override
  DiagnosticReport build() => DiagnosticReport(
    appVersion: '0.1.0',
    buildNumber: '1',
    platform: 'android',
    deviceModel: 'test-device',
    osVersion: '16',
    locale: 'bn',
    runtimeMode: 'test',
    events: const [],
  );
}

void main() {
  const locale = AppLocale.bangla;

  String t(String key) => AppText.get(locale, key);

  late InMemoryStore store;
  late AppServices services;

  Future<AppServices> buildServices() async {
    store = InMemoryStore();
    final repository = DefaultBusinessRepository(store);
    final collector = DiagnosticCollector();
    services = AppServices(
      store: store,
      repository: repository,
      onboarding: OnboardingService(repository),
      diagnostics: collector,
      exportService: DefaultExportService(
        store: store,
        reportSource: _FixedReportSource(),
      ),
      diagnosticsReportSource: _FixedReportSource(),
      shareService: _NoopShareService(),
      exportFileAdapter: () async => _FakeExportAdapter(),
      appVersionLabel: '0.1.0 (1)',
    );
    return services;
  }

  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WorkspaceHomePage(services: services, locale: locale),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> seedWorkspace() async {
    await store.saveBusinessProfile(
      const BusinessProfile(
        id: 'p1',
        name: 'Demo Shop',
        workspaceKind: WorkspaceKind.business,
        businessType: BusinessType.retail,
      ),
    );
  }

  testWidgets('empty workspace shows the smart empty state', (tester) async {
    await buildServices();
    await seedWorkspace();
    await pumpHome(tester);

    expect(find.text(t('no_transactions')), findsOneWidget);
    expect(find.text(t('no_transactions_hint')), findsOneWidget);
    // new_sale appears on both the FAB label and the action bar row
    expect(find.text(t('new_sale')), findsNWidgets(2));
    expect(find.text('Demo Shop'), findsOneWidget);
  });

  testWidgets('recent transactions show totals, due and status', (
    tester,
  ) async {
    await buildServices();
    await seedWorkspace();
    await store.saveTransaction(
      TransactionRecord(
        id: 't1',
        type: TransactionType.sale,
        createdAt: DateTime(2026, 8, 26),
        paymentStatus: PaymentStatus.partial,
        paidMinor: 30000,
        lines: const [
          TransactionLine(
            id: 'l1',
            description: 'Mouse',
            quantity: 1,
            sellingPriceMinor: 55000,
          ),
          TransactionLine(
            id: 'l2',
            description: 'Windows setup',
            quantity: 1,
            sellingPriceMinor: 85000,
          ),
        ],
      ),
    );
    await pumpHome(tester);

    expect(find.text('Mouse'), findsOneWidget);
    expect(
      find.text(t('more_lines').replaceFirst('{count}', '1')),
      findsOneWidget,
    );
    // Total ৳১৪০০, due ৳১১০০ in Bangla mode (Bangla numerals).
    expect(find.text('৳১৪০০'), findsOneWidget);
    expect(find.text('${t('due')}: ৳১১০০'), findsOneWidget);
    expect(find.text(t('partial_status')), findsOneWidget);
  });

  testWidgets('new sale opens the sale entry screen', (tester) async {
    await buildServices();
    await seedWorkspace();
    await pumpHome(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.byType(SaleEntryScreen), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(SaleEntryScreen), findsNothing);
    expect(find.text(t('no_transactions')), findsOneWidget);
  });
}
