import 'package:flutter_test/flutter_test.dart';
import 'package:naham_app/core/constants/app_constants.dart';
import 'package:naham_app/core/router/app_router.dart';
import 'package:naham_app/models/user_model.dart';

void main() {
  test('cookStatus routes approved cooks to the cook dashboard', () {
    expect(
      AppRouter.resolveCookStatusRoute(_cook(AppConstants.cookApproved)),
      AppRoutes.cookDashboard,
    );
  });

  test('cookStatus routes pending verification cooks to waiting approval', () {
    expect(
      AppRouter.resolveCookStatusRoute(
        _cook(AppConstants.cookPendingVerification),
      ),
      AppRoutes.cookWaitingApproval,
    );
  });

  test('cookStatus routes rejected or missing status to verification upload',
      () {
    expect(
      AppRouter.resolveCookStatusRoute(_cook(AppConstants.cookRejected)),
      AppRoutes.cookVerificationUpload,
    );
    expect(
      AppRouter.resolveCookStatusRoute(_cook(null)),
      AppRoutes.cookVerificationUpload,
    );
  });
}

UserModel _cook(String? cookStatus) {
  return UserModel(
    id: 'cook_1',
    name: 'Cook',
    email: 'cook@example.com',
    phone: '+966500000000',
    role: AppConstants.roleCook,
    cookStatus: cookStatus,
    createdAt: DateTime.parse('2026-05-11T00:00:00.000Z'),
  );
}
