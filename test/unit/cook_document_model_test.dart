import 'package:flutter_test/flutter_test.dart';
import 'package:naham_app/core/constants/app_constants.dart';
import 'package:naham_app/models/cook_document_model.dart';
import 'package:naham_app/models/user_model.dart';

void main() {
  test('builds only identity and health documents from the cook profile', () {
    final user = _cook(
      cookStatus: AppConstants.cookApproved,
      verificationIdUrl:
          'https://naham.example.com/users/cook_1/verification/id/id_card.pdf',
      verificationHealthUrl:
          'https://naham.example.com/users/cook_1/verification/health/health_certificate.pdf',
    );

    final documents = buildCookDocumentsFromUser(user);

    expect(documents, hasLength(2));
    expect(documents.map((doc) => doc.type), ['id', 'health']);
    expect(documents.map((doc) => doc.title), [
      'National ID',
      'Health Certificate',
    ]);
    expect(
      documents.map((doc) => doc.title),
      isNot(contains('Freelance Work Permit')),
    );
    expect(
      documents.map((doc) => doc.title),
      isNot(contains('Kitchen License')),
    );
    expect(documents.first.fileName, 'id_card.pdf');
    expect(documents.first.status, CookDocumentStatus.verified);
  });

  test('marks uploaded cook documents as pending until approval', () {
    final user = _cook(
      cookStatus: AppConstants.cookPendingVerification,
      verificationIdUrl:
          'https://naham.example.com/users/cook_1/verification/id/id_card.pdf',
    );

    final documents = buildCookDocumentsFromUser(user);

    expect(documents, hasLength(1));
    expect(documents.single.type, 'id');
    expect(documents.single.status, CookDocumentStatus.pending);
  });
}

UserModel _cook({
  required String cookStatus,
  String? verificationIdUrl,
  String? verificationHealthUrl,
}) {
  return UserModel(
    id: 'cook_1',
    name: 'Salma',
    email: 'salma@example.com',
    phone: '+966500000000',
    role: AppConstants.roleCook,
    createdAt: DateTime(2026, 5, 7),
    cookStatus: cookStatus,
    verificationIdUrl: verificationIdUrl,
    verificationHealthUrl: verificationHealthUrl,
  );
}
