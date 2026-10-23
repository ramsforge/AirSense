import 'package:flutter_test/flutter_test.dart';
import 'package:air_sense_client/main.dart';
import 'package:air_sense_client/services/network_service.dart';

void main() {
  testWidgets('AirSense app smoke test', (WidgetTester tester) async {
    final network = NetworkService();
    await tester.pumpWidget(AirSenseApp(network: network));
    expect(find.text('AirSense'), findsWidgets);
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });
}
