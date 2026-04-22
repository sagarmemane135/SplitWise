# Flutter App Folder Structure

## Workspace Root

SplitEase/
|- android/
|- ios/
|- linux/
|- macos/
|- web/
|- windows/
|- lib/
|- test/
|- docs/
|- pubspec.yaml
|- analysis_options.yaml
|- README.md

## App Structure (lib)

lib/
|- main.dart
|- app/
|  |- app.dart
|  |- router/
|  |  |- app_router.dart
|  |- theme/
|     |- app_theme.dart
|- bootstrap/
|  |- bootstrap.dart
|- core/
|  |- constants/
|  |- errors/
|  |- utils/
|  |- widgets/
|- data/
|  |- local/
|  |  |- datasources/
|  |  |- models/
|  |- p2p/
|  |  |- models/
|  |  |- protocol/
|  |  |- transport/
|  |- repositories/
|- domain/
|  |- entities/
|  |- repositories/
|  |- services/
|  |- usecases/
|- features/
|  |- onboarding/{data,domain,presentation/{pages,providers,widgets}}
|  |- groups/{data,domain,presentation/{pages,providers,widgets}}
|  |- members/{data,domain,presentation/{pages,providers,widgets}}
|  |- identity/{data,domain,presentation/{pages,providers,widgets}}
|  |- expenses/{data,domain,presentation/{pages,providers,widgets}}
|  |- shares/{data,domain,presentation/{pages,providers,widgets}}
|  |- debts/{data,domain,presentation/{pages,providers,widgets}}
|  |- manage/{data,domain,presentation/{pages,providers,widgets}}
|  |- collaboration/{data,domain,presentation/{pages,providers,widgets}}
|  |- export_pdf/{data,domain,presentation/{pages,providers,widgets}}
|  |- settings_reset/{data,domain,presentation/{pages,providers,widgets}}

## Test Structure

test/
|- unit/
|- widget/
|- integration/
|- widget_test.dart
