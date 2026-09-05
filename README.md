# DMP Begleiter

A personal, German-language iPhone/iPad companion for tracking a Disease Management Programme with a Hausarzt. Native SwiftUI, iOS 17+, no backend, accounts, analytics, external AI, or runtime third-party dependencies.

## Included

- Dashboard with dated measurement history and charts; different units remain separate.
- Camera document scanning, photo selection, and PDF/image file import.
- Native PDF rendering and German/English on-device OCR for scanned pages.
- Review-first extraction: explicit-unit lab/vital candidates and simple medication-plan candidates. Nothing becomes a measurement or medication without confirmation.
- Editable measurements, active/planned/past medications, dose instructions, start/end dates, and source links retained in the data model.
- Hausarzt appointments with questions, notes, and completion state; editable personal DMP name and agreed goals.
- Multipage PDF summary shared only through the iOS share sheet.
- Mandatory device authentication, background lock, app-switcher privacy cover, complete iOS file protection, and backup-exclusion flags.
- Deletion of reports and linked entries, or all app data.

The app launches empty. All test examples are synthetic. Never commit real medical documents, exports, credentials, or signing assets to this repository.

## Run on an iPhone

1. Open `DMPBegleiter.xcodeproj` with Xcode 16 or newer on a Mac.
2. Select the **DMPBegleiter** target → **Signing & Capabilities** → choose your Apple development team. Change the bundle identifier if necessary.
3. Connect an iPhone running iOS 17+ with a device passcode configured. Enable Developer Mode when prompted by iOS.
4. Select that device and run. Unlock the app with Face ID, Touch ID, or the device passcode.
5. Under **Mein DMP**, enter the programme, practice, and goals. Under **Berichte**, import a document, open its original, verify the measurement date and selected entries, then tap **Übernehmen**.

An Apple-signed build is required to install on a physical iPhone. This repository is source code, not an App Store or TestFlight release. Local simulator authentication requires configuring/enrolling simulated biometrics; camera scanning requires a physical supported device.

## Validation

```sh
swift test
xcodebuild -project DMPBegleiter.xcodeproj -scheme DMPBegleiter \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

GitHub Actions runs core tests and an unsigned simulator build. The deterministic project generator can be rerun after adding Swift files:

```sh
python3 scripts/generate_project.py
```

See [VALIDATION.md](VALIDATION.md) for the verification record and physical-device acceptance checks.

## Import behavior and limits

Maximum 25 MB / 30 pages per report. Password-protected PDFs are rejected. Images are normalized into PDFs. PDF pages with embedded text use that text; pages without text use Apple Vision OCR. Original pages remain viewable even when no text is found. Imports are processed off the UI thread. An exact input-byte hash detects repeat imports, but re-scanning the same physical report is not deduplicated.

Supported numeric suggestions: HbA1c (% or mmol/mol), weight (kg), explicitly labelled RR/blood pressure (mmHg), LDL and glucose (mg/dl or mmol/l), FEV1 (l or %). Recognition requires a labelled line and explicit unit. No unit conversion, diagnosis, health score, inferred target, or interpretation of whether a trend is good or bad.

Medication suggestions require a single line with a name, explicit strength, and a 3- or 4-slot numeric schedule, such as the synthetic `Beispielmittel 500 mg 1-0-1`. Every suggestion opens an editable form; the user must verify the start date and instructions. Complex plans, handwriting, tables with misordered OCR, liquid dosing, as-needed instructions, and unknown layouts need manual entry. Medication imports append entries; they never silently stop or replace existing medication. Check for existing entries before adding; end the old entry and add a new one for a dose change.

The review date starts at today's date and must be confirmed against the source. A report can contain multiple historical dates; import only values for the selected date, then add others manually with their actual dates. The app does not guess dates or decide which column in a complex laboratory table represents the latest result. Every suggested value is unchecked initially. OCR and embedded PDF text can be wrong or incomplete.

## Privacy and scope

Health data stays in the app's Application Support directory. The app does not initiate network requests and has no iCloud entitlement. iOS file protection depends on the device security configuration. Backup exclusion is a system hint, not a guarantee that bytes can never appear in any backup. Photos selected from a user's library may already be synchronized by that library's settings. Explicitly shared PDFs leave the app's protection boundary. Temporary export files are removed on share dismissal or the next unlock.

No automated cloud backup or restore is implemented. Device loss/deletion can lose data. PDF summaries are readable reports, not restorable app backups. There are no medication adherence logs, notifications, ePA, insurer submission, or practice integrations in this version.

This is an early personal tracking prototype. Personal use alone is not a certification or a determination of GDPR or medical-device status. No legal compliance certification is claimed. The app stores and displays user-reviewed information; it does not make clinical decisions. It is not an official DMP documentation or submission system.

## Architecture

- `Sources/DMPCore`: Codable records, conservative extraction, medication activity semantics.
- `App/HealthStore.swift`: atomic JSON persistence, report files, authentication, export/deletion.
- `App/DocumentService.swift`: camera bridge, PDF handling, OCR.
- `App/*View*.swift`: SwiftUI dashboard, import review, medication history, appointments/settings.
- `App/SummaryPDF.swift`: paginated TextKit PDF export.
- `Tests/DMPCoreTests`: unit parsing, ambiguous values, medication extraction/history and serialization.

## Primary references

- [G-BA: Disease Management Programmes](https://www.g-ba.de/themen/disease-management-programme/)
- [Apple: Recognizing text in images](https://developer.apple.com/documentation/vision/recognizing-text-in-images)
- [Apple: Document camera](https://developer.apple.com/documentation/visionkit/vndocumentcameraviewcontroller)
- [Apple: Complete file protection](https://developer.apple.com/documentation/foundation/fileprotectiontype/complete)
- [Apple: Backup exclusion](https://developer.apple.com/documentation/foundation/urlresourcevalues/isexcludedfrombackup)
