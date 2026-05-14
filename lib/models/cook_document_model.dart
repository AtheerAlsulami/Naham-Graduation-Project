import 'package:naham_app/core/constants/app_constants.dart';
import 'package:naham_app/models/user_model.dart';

enum CookDocumentStatus {
  verified,
  pending,
}

class CookDocumentItem {
  const CookDocumentItem({
    required this.id,
    required this.type,
    required this.title,
    required this.fileName,
    required this.url,
    required this.status,
  });

  final String id;
  final String type;
  final String title;
  final String fileName;
  final String url;
  final CookDocumentStatus status;
}

List<CookDocumentItem> buildCookDocumentsFromUser(UserModel? user) {
  if (user == null) {
    return const [];
  }

  final status = user.cookStatus == AppConstants.cookApproved
      ? CookDocumentStatus.verified
      : CookDocumentStatus.pending;
  final documents = <CookDocumentItem>[];

  void addDocument({
    required String id,
    required String type,
    required String title,
    required String? url,
    required String fallbackFileName,
  }) {
    final cleanUrl = (url ?? '').trim();
    if (cleanUrl.isEmpty) {
      return;
    }
    documents.add(
      CookDocumentItem(
        id: id,
        type: type,
        title: title,
        fileName: _fileNameFromUrl(cleanUrl, fallbackFileName),
        url: cleanUrl,
        status: status,
      ),
    );
  }

  addDocument(
    id: 'national-id',
    type: 'id',
    title: 'National ID',
    url: user.verificationIdUrl,
    fallbackFileName: 'national_id.pdf',
  );
  addDocument(
    id: 'health-certificate',
    type: 'health',
    title: 'Health Certificate',
    url: user.verificationHealthUrl,
    fallbackFileName: 'health_certificate.pdf',
  );

  return documents;
}

String _fileNameFromUrl(String url, String fallback) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.pathSegments.isEmpty) {
    return fallback;
  }

  final lastSegment = uri.pathSegments.last.trim();
  if (lastSegment.isEmpty) {
    return fallback;
  }
  return Uri.decodeComponent(lastSegment);
}
