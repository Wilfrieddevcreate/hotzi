import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'app.dart';
import 'data/sqlite_repository.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerFontLicenses();
  final state = AppState(await SqliteRepository.open());
  await state.load();
  runApp(HotziApp(state: state));
}

/// Les polices sont sous licence OFL : leur licence doit être livrée avec l'app.
void _registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final (name, file) in const [
      ('Bricolage Grotesque', 'OFL-BricolageGrotesque.txt'),
      ('Inter', 'OFL-Inter.txt'),
      ('JetBrains Mono', 'OFL-JetBrainsMono.txt'),
    ]) {
      yield LicenseEntryWithLineBreaks([name], await rootBundle.loadString('assets/fonts/$file'));
    }
  });
}
