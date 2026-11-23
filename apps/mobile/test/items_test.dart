import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:maimoni/api/models.dart';
import 'package:maimoni/theme.dart';
import 'package:maimoni/widgets/items.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  /// Shows one estimated item and opens its sheet. Answers the patches the row sends.
  Future<List<Json>> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final patches = <Json>[];
    final item = MonthItem(
      id: 'i1',
      monthId: 'm1',
      templateItemId: 't1',
      name: 'Energia',
      currency: Currency.eur,
      kind: EntryKind.expense,
      amount: 100,
      expression: null,
      paid: false,
      needsReview: true,
      position: 0,
    );
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      home: Scaffold(body: ItemRow(item: item, onUpdate: patches.add, onRemove: () {}, onPromote: () {})),
    ));
    await tester.tap(find.text('Energia'));
    await tester.pumpAndSettle();
    return patches;
  }

  testWidgets('confirming an estimate left as it is only clears the review', (tester) async {
    final patches = await open(tester);
    await tester.tap(find.text('Confirmar valor'));
    await tester.pumpAndSettle();
    expect(patches, [
      {'needsReview': false},
    ]);
  });

  testWidgets('confirming after typing another amount saves that amount', (tester) async {
    final patches = await open(tester);
    await tester.enterText(find.widgetWithText(TextField, '100'), '120');
    await tester.tap(find.text('Confirmar valor'));
    await tester.pumpAndSettle();
    expect(patches, [
      {'amount': 120.0, 'expression': null, 'needsReview': false},
    ]);
  });

  testWidgets('confirming an amount that is not a number keeps the sheet open and saves nothing', (tester) async {
    final patches = await open(tester);
    await tester.enterText(find.widgetWithText(TextField, '100'), 'abc');
    await tester.tap(find.text('Confirmar valor'));
    await tester.pumpAndSettle();
    expect(patches, isEmpty);
    expect(find.text('Número ou conta, ex.: 11,99+2,99'), findsOneWidget);
  });
}
