// Architecture rules for the local-first layer (ADR 0001):
//
//   - Screens never call the API. Only the sync layer (and the repositories that
//     predate it) may import the HTTP client.
//   - The clinical record screens read through providers over the LOCAL store.
//   - The network is never on the write path: the vitals repository must not
//     import the HTTP client or the transport.
//
// Presentation files that already import the HTTP client are listed below as a
// ratchet: the list may only shrink. A new offender fails this test.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _apiClient = 'core/api/';

/// Pre-existing offenders (back office, onboarding, dashboards). Remove entries
/// as those screens move behind providers; never add one.
const _legacyPresentationApiImports = <String>{
  'lib/presentation/auth/screens/register_provider_screen.dart',
  'lib/presentation/dashboard/screens/provider_dashboard_screen.dart',
  'lib/presentation/facilities/screens/facilities_list_screen.dart',
  'lib/presentation/facilities/screens/facility_form_screen.dart',
  'lib/presentation/more/more_screen.dart',
  'lib/presentation/more/org_admin_more_screen.dart',
  'lib/presentation/organization/screens/org_dashboard_screen.dart',
  'lib/presentation/providers/screens/provider_invitation_screen.dart',
  'lib/presentation/shell/org_admin_android_shell.dart',
  'lib/presentation/shell/org_admin_ios_shell.dart',
  'lib/presentation/shell/org_admin_web_shell.dart',
};

Iterable<File> _dartFiles(String dir) =>
    Directory(dir).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

List<String> _imports(File f) =>
    f.readAsLinesSync().where((l) => l.trimLeft().startsWith('import ') || l.trimLeft().startsWith('export ')).toList();

void main() {
  test('no new screen imports the HTTP client', () {
    final offenders = <String>{
      for (final f in _dartFiles('lib/presentation'))
        if (_imports(f).any((l) => l.contains(_apiClient))) f.path.replaceAll('\\', '/'),
    };

    expect(offenders.difference(_legacyPresentationApiImports), isEmpty,
        reason: 'Screens must go through a provider. New offenders: ${offenders.difference(_legacyPresentationApiImports)}');
    expect(_legacyPresentationApiImports.difference(offenders), isEmpty,
        reason: 'These no longer import the API client: remove them from the baseline so the ratchet tightens.');
  });

  test('the clinical record screens use providers, not repositories or the API', () {
    for (final f in _dartFiles('lib/presentation/patients')) {
      for (final line in _imports(f)) {
        expect(line.contains(_apiClient), isFalse, reason: '${f.path}: $line');
        expect(line.contains('data/repositories/'), isFalse, reason: '${f.path}: $line');
        expect(line.contains('core/localfirst/sync_'), isFalse, reason: '${f.path}: $line');
      }
    }
  });

  test('the network is not on the vitals write path', () {
    for (final name in ['vitals_repository.dart', 'local_store.dart']) {
      final imports = _imports(File('lib/core/localfirst/$name')).join('\n');
      expect(imports.contains(_apiClient), isFalse, reason: name);
      expect(imports.contains('sync_transport.dart'), isFalse, reason: name);
      expect(imports.contains('package:dio'), isFalse, reason: name);
    }
  });

  test('only the transport imports the HTTP client within the local-first layer', () {
    for (final f in _dartFiles('lib/core/localfirst')) {
      final path = f.path.replaceAll('\\', '/');
      if (path.endsWith('sync_transport.dart')) continue;
      expect(_imports(f).any((l) => l.contains(_apiClient)), isFalse, reason: path);
    }
  });
}
