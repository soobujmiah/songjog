import 'package:flutter_test/flutter_test.dart';
import 'package:songjog/app/app_services.dart';
import 'package:songjog/application/onboarding/onboarding_service.dart';
import 'package:songjog/data/export/share_service.dart';
import 'package:songjog/data/local/in_memory_store.dart';
import 'package:songjog/domain/models/business_profile.dart';
import 'package:songjog/domain/models/customer.dart';
import 'package:songjog/domain/models/product.dart';
import 'package:songjog/domain/models/transaction.dart';
import 'package:songjog/domain/services/export_payload.dart';
import 'package:songjog/data/repositories/business_repository.dart';
import 'package:songjog/domain/services/diagnostic_collector.dart';
import 'package:songjog/domain/services/diagnostic_event.dart';
import 'package:songjog/domain/services/diagnostic_report.dart';
import 'package:songjog/domain/services/export_service_impl.dart';
import 'package:songjog/l10n/app_text.dart';
import 'package:songjog/main.dart';
import 'package:songjog/presentation/settings/settings_screen.dart';

class _FakeExportAdapter implements ExportFileAdapter {
  ExportPayload? lastPayload;
  String? lastPath;

  @override
  Future<String> save(ExportPayload payload) async {
    lastPayload = payload;
    lastPath = 'memory:/${payload.filename}';
    return lastPath!;
  }

  @override
  Future<void> share(ExportPayload payload) async {}
}

class _RecordingShareService implements ShareService {
  final List<({String path, String mimeType, String? title})> calls = [];

  bool succeed = true;

  @override
  Future<bool> shareFile({
    required String path,
    required String mimeType,
    String? title,
  }) async {
    calls.add((path: path, mimeType: mimeType, title: title));
    return succeed;
  }
}

class _ThrowingStore implements LocalStore {
  @override
  Future<void> saveBusinessProfile(BusinessProfile profile) async =>
      throw StateError('disk failure');

  @override
  Future<BusinessProfile?> loadBusinessProfile() async =>
      throw StateError('disk failure');

  @override
  Future<void> saveTransaction(TransactionRecord transaction) async {}

  @override
  Future<List<TransactionRecord>> loadTransactions() async =>
      throw StateError('disk failure');

  @override
  Future<void> saveCustomer(Customer customer) async =>
      throw StateError('disk failure');

  @override
  Future<void> deleteCustomer(String id) async =>
      throw StateError('disk failure');

  @override
  Future<List<Customer>> getCustomers() async =>
      throw StateError('disk failure');

  @override
  Future<Customer?> getCustomer(String id) async =>
      throw StateError('disk failure');

  @override
  Future<void> saveProduct(Product product) async =>
      throw StateError('disk failure');

  @override
  Future<void> deleteProduct(String id) async =>
      throw StateError('disk failure');

  @override
  Future<List<Product>> getProducts() async =>
      throw StateError('disk failure');

  @override
  Future<Product?> getProduct(String id) async =>
      throw StateError('disk failure');

  @override
  Future<Map<String, dynamic>> getFinancialSummary({
    DateTime? from,
    DateTime? to,
  }) async =>
      throw StateError('disk failure');
}

class _FixedReportSource implements DiagnosticReportSource {
  @override
  DiagnosticReport build() {
    return DiagnosticReport(
      appVersion: '0.1.0',
      buildNumber: '1',
      platform: 'android',
      deviceModel: 'test-device',
      osVersion: '16',
      locale: 'bn',
      runtimeMode: 'test',
      events: [
        DiagnosticEvent(
          timestamp: DateTime.utc(2026, 8, 26, 9),
          level: 'info',
          message: 'app started',
          category: 'lifecycle',
        ),
      ],
    );
  }
}

void main() {
  _FakeExportAdapter exportAdapter = _FakeExportAdapter();
  late InMemoryStore store;
  late DiagnosticCollector collector;
  late _RecordingShareService shareService;
  late AppServices services;

  Future<AppServices> buildServices() async {
    store = InMemoryStore();
    await store.saveBusinessProfile(const BusinessProfile(
      id: 'p1',
      name: 'Test Business',
      workspaceKind: WorkspaceKind.business,
      businessType: BusinessType.retail,
    ));
    await store.saveTransaction(TransactionRecord(
      id: 't1',
      type: TransactionType.sale,
      createdAt: DateTime(2026, 8, 26),
      paymentStatus: PaymentStatus.paid,
      paidMinor: 1000,
      lines: const [
        TransactionLine(
          id: 'l1',
          description: 'Item',
          quantity: 1,
          sellingPriceMinor: 1000,
        ),
      ],
    ));
    collector = DiagnosticCollector();
    shareService = _RecordingShareService();
    final repository = DefaultBusinessRepository(store);
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
      shareService: shareService,
      exportFileAdapter: () async => exportAdapter,
      appVersionLabel: '0.1.0 (1)',
    );
    return services;
  }

  setUp(() async {
    await buildServices();
  });

  // A pre-existing workspace opens the app directly on the workspace home
  // (no welcome page), from which settings remain reachable.
  testWidgets('settings are reachable from the workspace home',
      (tester) async {
    await tester.pumpWidget(SongjogApp(services: services));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip(AppText.get(AppLocale.bangla, 'settings')));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text(AppText.get(AppLocale.bangla, 'settings_title')),
        findsOneWidget);
  });

  testWidgets('export controls are visible with their labels', (tester) async {
    await tester.pumpWidget(SongjogApp(services: services));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(AppText.get(AppLocale.bangla, 'settings')));
    await tester.pumpAndSettle();

    expect(
      find.text(AppText.get(AppLocale.bangla, 'export_my_data')),
      findsOneWidget,
    );
    expect(
      find.text(AppText.get(AppLocale.bangla, 'export_diagnostics')),
      findsOneWidget,
    );
  });

  testWidgets('user-data export saves a file and shows the success state',
      (tester) async {
    await tester.pumpWidget(SongjogApp(services: services));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(AppText.get(AppLocale.bangla, 'settings')));
    await tester.pumpAndSettle();

    await tester.tap(
      find.text(AppText.get(AppLocale.bangla, 'export_my_data')),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppText.get(AppLocale.bangla, 'export_saved')),
        findsOneWidget);

    final payload = exportAdapter.lastPayload;
    expect(payload, isNotNull);
    expect(payload!.filename, startsWith('songjog_data_'));
    expect(payload.filename, endsWith('.json'));
    expect(payload.mimeType, 'application/json');
    expect(payload.content, contains('Test Business'));
    expect(payload.content, contains('"t1"'));

    final exportEvents = collector.events
        .where((e) => e.category == 'export' && e.level == 'info')
        .toList();
    expect(exportEvents, isNotEmpty);
  });

  testWidgets('share action hands the saved file to the share service',
      (tester) async {
    await tester.pumpWidget(SongjogApp(services: services));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(AppText.get(AppLocale.bangla, 'settings')));
    await tester.pumpAndSettle();

    await tester.tap(
      find.text(AppText.get(AppLocale.bangla, 'export_my_data')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppText.get(AppLocale.bangla, 'share')));
    await tester.pumpAndSettle();

    expect(shareService.calls, hasLength(1));
    expect(shareService.calls.single.mimeType, 'application/json');
    expect(shareService.calls.single.path, exportAdapter.lastPath);
    expect(shareService.calls.single.title, exportAdapter.lastPayload!.filename);
  });

  testWidgets('diagnostic export produces a diagnostic payload', (tester) async {
    await tester.pumpWidget(SongjogApp(services: services));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(AppText.get(AppLocale.bangla, 'settings')));
    await tester.pumpAndSettle();

    await tester.tap(
      find.text(AppText.get(AppLocale.bangla, 'export_diagnostics')),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppText.get(AppLocale.bangla, 'export_saved')),
        findsOneWidget);

    final payload = exportAdapter.lastPayload!;
    expect(payload.filename, startsWith('songjog_diagnostics_'));
    final content = payload.content;
    expect(content, contains('"kind": "diagnostic"'));
    expect(content, contains('"app_version": "0.1.0"'));
    expect(content, contains('app started'));
  });

  testWidgets('language options are visible and reachable', (tester) async {
    await tester.pumpWidget(SongjogApp(services: services));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(AppText.get(AppLocale.bangla, 'settings')));
    await tester.pumpAndSettle();

    expect(find.text(AppText.get(AppLocale.bangla, 'language')), findsOneWidget);
    expect(
      find.text(AppText.get(AppLocale.bangla, 'language_bangla')),
      findsOneWidget,
    );
    expect(
      find.text(AppText.get(AppLocale.bangla, 'language_english')),
      findsOneWidget,
    );
  });

  testWidgets('a failing store shows the error state and records it',
      (tester) async {
    final throwing = _ThrowingStore();
    final brokenRepository = DefaultBusinessRepository(throwing);
    final broken = AppServices(
      store: throwing,
      repository: brokenRepository,
      onboarding: OnboardingService(brokenRepository),
      diagnostics: collector,
      exportService: DefaultExportService(store: _ThrowingStore()),
      diagnosticsReportSource: _FixedReportSource(),
      shareService: shareService,
      exportFileAdapter: () async => exportAdapter,
      appVersionLabel: '0.1.0 (1)',
    );
    await tester.pumpWidget(SongjogApp(services: broken));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(AppText.get(AppLocale.bangla, 'settings')));
    await tester.pumpAndSettle();

    await tester.tap(
      find.text(AppText.get(AppLocale.bangla, 'export_my_data')),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining(AppText.get(AppLocale.bangla, 'export_failed')),
        findsOneWidget);

    final errors = collector.events
        .where((e) => e.category == 'export' && e.level == 'error')
        .toList();
    expect(errors, isNotEmpty);
    expect(errors.last.message, 'export failed');
  });
}
