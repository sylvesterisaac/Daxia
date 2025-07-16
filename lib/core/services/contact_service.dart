import 'package:permission_handler/permission_handler.dart';

class ContactService {
  get ContactsService => null;

  Future<List<String>> getNormalizedPhoneNumbers() async {
    final permissionStatus = await Permission.contacts.request();
    if (!permissionStatus.isGranted) return [];

    final contacts = await ContactsService.getContacts(withThumbnails: false);
    final phoneNumbers = <String>{};

    for (final contact in contacts) {
      for (final phone in contact.phones ?? []) {
        final normalized = _normalizePhoneNumber(phone.value ?? '');
        if (normalized.isNotEmpty) {
          phoneNumbers.add(normalized);
        }
      }
    }

    return phoneNumbers.toList();
  }

  // Normalize: Remove spaces, dashes, parentheses
  String _normalizePhoneNumber(String number) {
    return number.replaceAll(RegExp(r'[^\d+]'), '');
  }
}
