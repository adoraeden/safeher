import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:women_safety/models/incident_report.dart';
import 'package:women_safety/screens/incidents/report_incident_screen.dart';
import 'package:women_safety/services/incident_service.dart';

class FakeIncidentService extends IncidentService {
  IncidentReport? lastSubmittedReport;
  bool shouldThrow = false;

  @override
  Future<void> submitReport({
    required String type,
    String? category,
    required String description,
    String severity = 'medium',
    bool isActive = true,
    DateTime? occurredAt,
    double? lat,
    double? lng,
    String? locationName,
    String? additionalNotes,
  }) async {
    if (shouldThrow) {
      throw Exception('Simulated network error');
    }
    lastSubmittedReport = IncidentReport(
      id: 'fake_id_123',
      type: type,
      category: category ?? type,
      description: description,
      severity: severity,
      isActive: isActive,
      occurredAt: occurredAt ?? DateTime.now(),
      lat: lat,
      lng: lng,
      locationName: locationName,
      additionalNotes: additionalNotes,
      timestamp: DateTime.now(),
      reporterId: 'fake_user_uid',
    );
  }
}

Future<void> pumpStep(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('ReportIncidentScreen renders all required reporting sections', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final fakeService = FakeIncidentService();

    await tester.pumpWidget(
      MaterialApp(
        home: ReportIncidentScreen(incidentService: fakeService),
      ),
    );
    await pumpStep(tester);

    // Verify Screen Title
    expect(find.text('Report Hazard'), findsOneWidget);

    // Verify Categories
    expect(find.text('Hazard Category'), findsOneWidget);
    expect(find.text('Personal Safety'), findsOneWidget);
    expect(find.text('Environment & Lighting'), findsOneWidget);
    expect(find.text('Suspicious Activity'), findsOneWidget);
    expect(find.text('Transit & Commute'), findsOneWidget);
    expect(find.text('Other Hazards'), findsOneWidget);

    // Verify Severity options
    expect(find.text('Severity Level'), findsOneWidget);
    expect(find.text('Low'), findsOneWidget);
    expect(find.text('Medium'), findsOneWidget);
    expect(find.text('High'), findsOneWidget);
    expect(find.text('Critical'), findsOneWidget);

    // Verify Location section
    expect(find.text('Hazard Location'), findsOneWidget);
    expect(find.text('Include hazard location'), findsOneWidget);

    // Verify Written Description
    expect(find.text('Written Description'), findsOneWidget);

    // Verify Timing & Active Status
    expect(find.text('When did this happen?'), findsOneWidget);
    expect(find.text('Happened Just Now'), findsOneWidget);
    expect(find.text('Earlier Time'), findsOneWidget);
    expect(find.text('Hazard is currently active'), findsOneWidget);

    // Verify Additional Notes
    expect(find.text('Additional Notes & Advice'), findsOneWidget);

    // Verify Submit button
    expect(find.text('Submit Hazard Report'), findsOneWidget);
  });

  testWidgets('Category selection switches specific hazard types', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final fakeService = FakeIncidentService();

    await tester.pumpWidget(
      MaterialApp(
        home: ReportIncidentScreen(incidentService: fakeService),
      ),
    );
    await pumpStep(tester);

    // Initially Personal Safety types are visible
    expect(find.text('Harassment / Catcalling'), findsOneWidget);
    expect(find.text('Stalking / Following'), findsOneWidget);

    // Switch to Environment & Lighting
    await tester.tap(find.text('Environment & Lighting'));
    await pumpStep(tester);

    expect(find.text('Poor / Broken Streetlights'), findsOneWidget);
    expect(find.text('Deserted / Isolated Pathway'), findsOneWidget);

    // Switch to Suspicious Activity
    await tester.tap(find.text('Suspicious Activity'));
    await pumpStep(tester);

    expect(find.text('Suspicious Person / Loitering'), findsOneWidget);
    expect(find.text('Suspicious Vehicle'), findsOneWidget);
  });

  testWidgets('Validates description field before submission', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final fakeService = FakeIncidentService();

    await tester.pumpWidget(
      MaterialApp(
        home: ReportIncidentScreen(incidentService: fakeService),
      ),
    );
    await pumpStep(tester);

    final submitBtn = find.text('Submit Hazard Report');
    await tester.ensureVisible(submitBtn);
    await tester.tap(submitBtn);
    await pumpStep(tester);

    // Error for empty description
    expect(find.text('Please describe the hazard.'), findsOneWidget);

    // Find the description TextFormField
    final textFields = find.byType(TextFormField);
    // Landmark is index 0, Description is index 1
    await tester.enterText(textFields.at(1), 'Too short');
    await tester.tap(submitBtn);
    await pumpStep(tester);

    expect(find.text('Please provide more detail (at least 10 characters).'), findsOneWidget);
  });

  testWidgets('Full submission flow displays clear success view with report summary', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final fakeService = FakeIncidentService();

    await tester.pumpWidget(
      MaterialApp(
        home: ReportIncidentScreen(incidentService: fakeService),
      ),
    );
    await pumpStep(tester);

    // 1. Select Infrastructure category
    await tester.tap(find.text('Environment & Lighting'));
    await pumpStep(tester);

    // 2. Select Poor / Broken Streetlights type
    await tester.tap(find.text('Poor / Broken Streetlights'));
    await pumpStep(tester);

    // 3. Select High severity
    await tester.tap(find.text('High'));
    await pumpStep(tester);

    // 4. Fill in description & landmark
    final textFields = find.byType(TextFormField);
    await tester.enterText(textFields.at(0), 'Corner of 4th Ave and Elm St');
    await tester.enterText(
      textFields.at(1),
      'Entire block has no working lights, very pitch dark alley.',
    );
    await tester.enterText(textFields.at(2), 'Walk on opposite side where shops are illuminated.');

    // 5. Submit
    final submitBtn = find.text('Submit Hazard Report');
    await tester.ensureVisible(submitBtn);
    await tester.tap(submitBtn);
    await pumpStep(tester);

    // 6. Verify service was called with proper structured data
    expect(fakeService.lastSubmittedReport, isNotNull);
    final submitted = fakeService.lastSubmittedReport!;
    expect(submitted.category, 'infrastructure');
    expect(submitted.type, 'poor_lighting');
    expect(submitted.severity, 'high');
    expect(submitted.isActive, true);
    expect(submitted.locationName, 'Corner of 4th Ave and Elm St');
    expect(submitted.additionalNotes, 'Walk on opposite side where shops are illuminated.');
    expect(submitted.description, 'Entire block has no working lights, very pitch dark alley.');

    // 7. Verify Success State View is rendered
    expect(find.text('Report Submitted'), findsOneWidget);
    expect(find.text('Thank You for Reporting'), findsOneWidget);
    expect(find.text('REPORT SUMMARY'), findsOneWidget);
    expect(find.text('Environment & Lighting'), findsOneWidget);
    expect(find.text('Poor / Broken Streetlights'), findsOneWidget);
    expect(find.text('Currently Active'), findsOneWidget);
    expect(find.text('Corner of 4th Ave and Elm St'), findsOneWidget);
    expect(find.text('View on Safety Map'), findsOneWidget);
    expect(find.text('Back to Dashboard'), findsOneWidget);
  });

  testWidgets('Submission error displays actionable error banner', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final fakeService = FakeIncidentService()..shouldThrow = true;

    await tester.pumpWidget(
      MaterialApp(
        home: ReportIncidentScreen(incidentService: fakeService),
      ),
    );
    await pumpStep(tester);

    final textFields = find.byType(TextFormField);
    await tester.enterText(
      textFields.at(1),
      'Suspicious individual following commuters on subway stairs.',
    );

    final submitBtn = find.text('Submit Hazard Report');
    await tester.ensureVisible(submitBtn);
    await tester.tap(submitBtn);
    await pumpStep(tester);

    // Verify Error Banner is shown
    expect(find.text('Submission Failed'), findsOneWidget);
    expect(find.text('Simulated network error'), findsOneWidget);
  });
}
