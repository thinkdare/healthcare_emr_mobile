import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_emr_mobile/data/models/models.dart';

void main() {
  group('UserModel.isOrgAdmin', () {
    test('returns true when userType is org_admin', () {
      final user = UserModel(
        id: 'u1',
        email: 'admin@test.com',
        name: 'Admin User',
        userType: 'org_admin',
        twoFactorEnabled: false,
      );
      expect(user.isOrgAdmin, isTrue);
    });

    test('returns false when userType is staff', () {
      final user = UserModel(
        id: 'u2',
        email: 'staff@test.com',
        name: 'Staff User',
        userType: 'staff',
        twoFactorEnabled: false,
      );
      expect(user.isOrgAdmin, isFalse);
    });
  });
}
