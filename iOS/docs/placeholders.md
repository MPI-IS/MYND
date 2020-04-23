Back to [index](./index.md)

# Placeholders, localization, data structures, and options

## Placeholders
For announcements, in preparation steps, and in feedback, you can use placeholders that will be filled in by the application during display. Placeholders are encapsulated by `#`, as are localizable strings. The `mutatingWithFilledPlaceholders` extension of the String class fills out placeholders, either with a localized string, with a user-default, or with an optional `String:String` dictionary that is passed. The following placeholders are available without additional arguments:
- From user defaults: `#patientName#`, `#helperName#`
- Localizables: `#participant#`, `#helper#`, `#ofPatient#`, `#of#`, `#possessivePatient#`, `#your#` (these are placeholders because the hardware preparation text needs to change based on whether a helper is present or not. See `Steps_en.json` as an example.)

## Localization
The app features three ways to localize any strings presented to the user. At the time of development, German and English were supported.
- Text in Swift classes: This is solved with the `NSLocalizedString` function. Available placeholders and translations can be found in `Locaziable.strings`.
- Text in the user interface: This is solved directly in `Main.storyboard` with object identifiers.
- Text in questionnaires, consent, and preparation steps: This is solved with different JSON files. The application will automatically search for `[name]_[locale].json` and return an error if it cannot be found (e.g., `Steps_en.json` is the english version of the JSON file that contains all hardware preparation steps).

Note that recording scenarios are not realized with JSON files but rather through direct implementation in the model classes, and therefore `NSLocalizedString` usage, at this time.

## Data structures

### Study content
For examples of study content structure, please refer to `initial_en.json` for a questionnaire structure, `mynd_example_consent_en.json` for a consent structure, and `Steps_en.json` for hardware preparation steps. Refer to the [Models and study content](./models.md) section for more details on EEG recordings.

### Stored files
Questionnaires and EEG recordings are stored in specific file structures to make offline processing more convenient. Both file types also contain some meta information that is collected during the session.
- Questionnaires are stored as JSON file in a `identifier : answer` format. Display and preprocessing is handled by `QuestionnaireViewController` and passed to `StorageController` for storage.
- EEG recordings are stored as HDF5 file. The structure is outlined in `StorageController`. In general, the file contains two groups of data:
  - Recording: ChannelNames, Raw Data Matrix, Marker Channel, TimeStamp Channel, SessionID, RunID, Version, and any attribute that is collected during the session by `SessionView`
  - Paradigm: Name, Condition Labels, Baseline Markers, Baseline Time, Trial Time, No. Conditions

See `supplements` for an example on how to load these in MATLAB.

## Options
You can configure the application in two ways. Via `Setup`, and during app execution in settings. "User Preferences" are always available to the user, options below are only available after entering the developer password. Please see the detailed comments in the `Setup` class for more information. Developer mode can also be enabled through iOS Settings.