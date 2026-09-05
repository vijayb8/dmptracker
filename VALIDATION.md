# Validation record

The creation environment is Linux without Swift, Xcode, an iOS simulator, or an Apple signing identity. Local work does not establish a successful iOS build or a tested camera/authentication experience. GitHub Actions is configured to run `swift test` and an unsigned iOS Simulator build; consult the actual run result for compiler/test status.

Local validation covers the generated project references, XML/plist/asset syntax, source syntax parsing when available, absence of backend/analytics SDKs, and review of import/persistence behavior. Core unit tests cover German decimals, rejected ambiguous/unitless values, explicit blood-pressure pairs, unit separation, medication schedule extraction, invalid numbers, medication date boundaries, and JSON round trips.

## Physical-device acceptance before using real records

- Launch with passcode and biometrics; cancel authentication; background/foreground; verify protected screens never appear before authentication.
- Scan a multi-page synthetic report; select a rotated photo; import a text PDF and a scanned PDF. Verify original pages, selected values, units, and dates against each source.
- Import a mixed-layout PDF, empty-text scan, unsupported file, encrypted PDF, over-limit PDF, and exact duplicate. Confirm clear failure/empty extraction rather than invented values.
- Leave every candidate unchecked: only the original report should save. Cancel: nothing should persist. Add a medication suggestion and verify all fields; an existing medication must remain unchanged.
- Add and correct measurements, relaunch, and compare each chart's units and dates. Confirm a single measurement does not imply a trend.
- Add/end a medication, add a future start, relaunch, and inspect current/history sections.
- Create/edit/complete an appointment. Confirm no reminder or clinical interval is promised.
- Export with long notes and enough data for multiple pages; inspect every page for clipping and completeness. Dismiss the share sheet and verify temporary file removal.
- Delete a report and its linked values; erase all app data; verify no report/export files remain. Simulate a persistence failure and confirm an error rather than a success message.

Known limits: no device UI tests yet; no OCR accuracy claim; no automatic backups/restore, daily medication adherence, or notifications. Complex clinical documents need careful manual review.
