import "package:flutter_test/flutter_test.dart";
import "package:workgo_karya/main.dart";

void main() {
  test("Karya App smoke test", () {
    const app = WorkGoKaryaApp();
    expect(app, isNotNull);
  });
}
