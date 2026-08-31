import "package:flutter_test/flutter_test.dart";
import "package:workgo_customer/main.dart";

void main() {
  test("Customer App smoke test", () {
    const app = WorkGoCustomerApp();
    expect(app, isNotNull);
  });
}
