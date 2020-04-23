# Documentation

This technical documentation covers the most important features of the MYND iOS app. 
It was written for researchers that are looking to incorporate MYND into their own work. 
Some experience with programming in general, and ideally with mobile application development, are recommended.
For an in-depth review, please take a look at the additional comments in the code.
Important functions are named in this documentation and can be found via full-text search.
For a scientific discussion of this platform, please refer to the referenced papers on the main page.

## Table of Contents
- [Models and study content](./models.md)
- [Data recording, processing, storage, and transmission](./data.md)
- [Placeholders, localization, options, and structures](./placeholders.md)
- [User interface](./ui.md)
- [Other](./other.md)

## General programming patterns
- In general, the application follows the model-view-controller (MVC) pattern for anything that is related to the *sequential* tasks of the participant. Note that `View` and `ViewController` are used interchangeably in this documentation. 
- EEG time series processing and storage, as well as some internal *signals* and errors are handled with the Observer Pattern (with RxSwift).
- Functions that are needed *globally* are realized as singletons (e.g., Text-To-Speech, Data Storage, Data Transmission)

## What you may want to change
Below you find a few example of adaptations that you may want to make to use MYND for your own research. These are not meant to be exhaustive how-tos, but rather as pointers for likely future developments and quick incorporation into your own work.

### Use a headset other than the Muse EEG
The application was tested with the Muse EEG headset, however signal processing and storage, as well as the user interface are independent of the employed recording hardware. In fact, the application already features a *Generic Oscillator* that can be used instead of a physical headset to test the application without making any changes in the code. As long as the device is capable of 1) connecting via bluetooth 2) recording biosignals, and 3) sending them as an array values over time, it can be implemented in this application without changing the general logic.

If you wish to implement support for a different recording device, you need to create a new interfacing class for this specific hardware that conforms to the `DataSource` protocol. If done correctly, `DataController` can instantiate this class and abstract the data processing from there. In detail:

1. Find recording hardware that can interface with iOS via BLE or Bluetooth 4.0 (pre-paring required), use the SDK, if any, to establish a connection to the device.
2. Create a new class that interfaces with the device and implements the `DataSource` protocol. The existing devices may serve as a blueprint. Make sure that your class can detect (or emulate) the signals listed in the `DeviceStates` enum, as those may be needed for guided hardware preparation. You could also remove unwanted completion requirements in `steps_en.json`.
3. Add the device to the `Devices` enum in `DataController`. Instruct `DataController` on how to instantiate this device in `setDataSource`.
4. The application was designed for 4 or 5 channels (by enabling `isAuxEnabled` in `Setup`). If your channel count differs, you will need to 1) make this channel count known to `DataController`. This is currently done by `SessionView` when a recording session starts. 2) Adapt `FittingView` in both layout and functionality. 3) Change, create, or remove `DeviceStates` signals: The "good signal" functions currently toggles `SignalQualityView`s at specific indices in `FittingView` which may not be applicable with a different channel setup. You could also remove them in as completion functions in `steps_en.json`.
5. Adapt the remaining hardware preparation steps in `steps_en.json` and associated media to reflect your hardware.

Processing, recording, storage, and transmission are abstracted from the specific device and should therefore be unaffected by these changes. See [Data recording, processing, storage, and transmission](./data.md) for more information.

### Implement different EEG recording scenarios, trials, or phases
Extend the scenario, trial, and phase enums with the name of your new content. The `makeRecordingScenario` function of `ScenarioModel` needs to have one static function per enum to create the respective scenario object, you can use the existing ones as blueprint. Add a thumbnail for your new scenario here. Then, `TrialModel` and `PhaseModel` host the specifics of your new content. Have a look at the `.mentalSubtraction` trial case for a trial-type that contains some more logic than just displaying a string. Create localized strings in `Localizable.strings` for your content to display it in the current device language. See [Models and study content](./models.md) on more details on how EEG recording scenarios are structured.

### Show images or other visual feedback
Some preliminary feedback functionality had been implemented and was left in the code to be expanded upon (see [Other](./other.md)). If you would like to present visual stimuli, have a look at the following:

1. You need to extend the `PhaseModel` such that it can (optionally) contain media other than strings. The respective stimuli need to be added to the project, and then potentially shuffled and attached during trial generation in `TrialModel`.
2. You need to alter `ScenarioView` such that it behaves differently when a phase contains images. To do so, you may build upon `FeedbackView`, which already covers the whole screen but is inactive: You could add a `UIImageView` to it in `Main.storyboard` and have it display the optional image, if any.

If you would like to present feedback, `Feedback` enum contains basic options to turn feedback on or off on phase-level. If you choose something other than `.none`, `FeedbackView` will currently display a moving waveform based on computations in `FeedbackController`. Calibration phases, where mean or standard deviation are updated, are also already supported. Either the computation or display could be adapted.

### Add other questionnaires or question types
To add other questionnaires extend the scenario enum with the name of your new content. The `makeQuestionnaireScenario` function of `ScenarioModel` will use `DocumentController` to look for a JSON file named `[name]_[locale].json`, and create the scenario object based on that. Have a look at existing questionnaires for the structure of these files. 

To add a new question type, `QuestionGenerator` needs to be extended. Here, one function per type, defined in the `type` key of the JSON object, is implemented. The function needs to return an `ORKStep` which is later displayed with *ResearchKit*. Have a look at existing functions as blueprint.

### Add different processing pipelines
`ProcessingDelegate` handles signal processing. It observes raw data emitted by `DataController`, and currently emits signal quality or band-power. To add another processing pipeline, you first name it in the `ProcessingMode` enum. Then, implement the processing function that would be called when calling `start` with that mode. If you want to add another observable to be emitted, first preallocate it in `preallocHelper` before you push new values into it. Have a look at existing communication between `DataController`, `ProcessingDelegate`, and `FittingView` to learn about the signal-observer pattern. Note that, currently, only one kind of processing can be performed at a time.

### Send parameters remotely
The application was designed such that the study can be completed without any internet connection. However, if you would like to outsource certain computations and return updated weights or other parameters to the application, you could make use of the `checkForMessage` function in `TransferController`. This currently only supports the download of JSON files from a webdav with short strings for general announcements. However, this JSON file can be extended to contain various other values, and the `setRemoteMessage` function in `BannerController` can be extended to process these values as needed.

### Make trials variable in length
Phases can already have a variable length if `duration` is set to 0, however, this is used for short welcome or goodbye prompts, which proceed once `TTSController` finishes. If you would like to build upon this functionality, you would need to add a variable that distinguished whether this variable phase proceeds after TTS finishes, or if another condition is met. Then, a similar system as the `completionSignal` pacing in `StepView` could be used to pace the recording: `ScenarioView` could be altered to subscribe to phase completion signals that are emitted elsewhere, check if the signal corresponds to the success condition of the current phase, and advance to the next phase. See [User interface](./ui.md) for details on how this is already implemented for hardware preparation and fitting.

### Add another language
See [localization](./other.md) for details on how this is implemented.

## What you __must__ change
Even if you plan to use this application as is, you __must__ change or check the following things to employ it:
1. Check licenses before installing pods: OpenPGP (used for encryption) and LibMuse (Muse interfacing) have a proprietary license. Please review them to see if you are eligible to use those libraries. Get in touch with business@interaxon.ca to learn more about using Muse for research.
2. Configure `Setup`: Review all options presented there, and provide your own credentials for webdav servers and, optionally, data transmission via e-mail.
3. Change the encryption key: __Never__ use the public and private key provided in this repository for a user study. They are only meant to display functionality. It is advisable to generate a new PGP key for every study.
4. Provide you own consent form. Note: If you do not wish to use the on-device consent function, you may alter the functionality based on the `skipSignup` function in `LoginView`. Make sure that you always generate a new UUID per subject.