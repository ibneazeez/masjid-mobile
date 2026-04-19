import 'package:flutter_test/flutter_test.dart';
import 'package:masjid_mobile/main.dart';

void main() {
  testWidgets('app boots to masjid list', (WidgetTester tester) async {
    await tester.pumpWidget(const MasjidApp());
    expect(find.text('Masjids of Nellore'), findsOneWidget);
  });
}
