Back to [index](./index.md)

# Other features, classes, and functions

## Banner controller
The `BannerController` is a collection of functions that handles the display of messages outside of the "regular" sequence. It takes care of downloading and settings announcement messages before starting a new scenario. It displays short messages as status bar banners, and also triggers acoustic notifications for certain events during recording. Lastly, it schedules an iOS notification whenever the current day time out date passed, to inform subjects that the next set of scenarios can be completed.

## Question generator
The `QuestionGenerator` is a collection of functions that take JSON arrays and turn them into concrete objects for display. It handles questionnaires with one function per supported question type. It also generates the consent views that are presented during boarding. See the `inital_en.json` and `mynd_consent_en.json` for examples of the JSON file structures.

## Wait view
See `HomeView` for more details. The `WaitView` is called immediately by home view if all scenarios were completed and the time out date has not passed yet. It displays various wait messages based on the current state.

## Feedback (unused)
A few feedback classes were implemented to provide visual feedback during recording, but ultimately remained unused. There are left in the code to be expanded upon. The `FeedbackController` was implemented to compute necessary statistics for feedback display. `ScenarioView`calls and controls the corresponding `FeedbackView`, that displays feedback as a moving wave on the whole screen. In terms of visuals, `ProgressView`, `CountdownTimer`, and `InstructionView` provide a visual representation of the required action during a trial, and remaining trial time.

## Extensions
The `Extension` file contains a collection of functions and variables that were used to extend existing functionality of Swift base classes throughout the application. Source URLs are indicated wherever applicable.

## The Data folder
This folder contains images and JSON files that are used throughout the application. It exists for convenience and it is not necessary to place such files there, as all resources are copied the the device on application root level anyways. Logos and icons are placed in the `Assets` container.

## App delegate
This is the entry point for the application. It also loads and sets an active study, if a corresponding save file was found in user defaults (see "models -> Study progression"). Note that device sleep mode is disabled while the application is running, to prevent the device from turning off during a recording. If a recording was happening when the app entered background, it is ended here.

## myndios-Bridging-Header.h
This file is needed to expose Obj-C libraries to the Swift classes. At the time of development, this was used for `Muse.framework` and `mailcore2`.