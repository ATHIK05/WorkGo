import "package:flutter_test/flutter_test.dart";
import "package:workgo_admin_console/main.dart";

void main() {
  test("Admin Console App smoke test", () {
    const app = WorkGoAdminApp();
    expect(app, isNotNull);
  });
}
