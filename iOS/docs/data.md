Back to [index](./index.md)

# Data recording, processing, storage, and transmission

This application stores consent forms as PDF, questionnaire responses as JSON, and recorded EEG data as HDF5 files. Data can be stored and/or transmitted in an encrypted fashion once the device is connected to WiFi. Data exchange between objects is realized with the signal-observer pattern.

## Safety measures

The following safety measures are in place to protect the recorded data. Options can be changed in `Setup`. For encryption, a valid OpenPGP license is required.
- After consenting to the study, a random *UUID* is generated and used as part of the filename for all recorded and transmitted files. The name of the participant is only displayed on the PDF of the consent form and set as a variable in the application. It is never publicly visible.
- All data can be encrypted during storage with the public key. In this case, the participant immediately loses all access to their data after recording, and data cannot be used for post-hoc processing and feedback.
- For transmission, the to-be transmitted data is encrypted, if not already stored in this way, with a public key. __Make sure that only the experimenter has access to the corresponding private key to decrypt the transmitted data.__ Transmission can be disabled.
- Data can be uploaded to a webdav server. __Make sure that the upload-account has no rights to download any data, and that all files in the remote directory are encrypted.__ The WebDav connection can be established with https to add an additional layer of safety.
- Announcements can be downloaded and displayed from a different webdav directory. These messages can contain placeholders for names that are filled out on the device only (see [placeholders](./placeholders.md)). __Make sure that only public information is stored in this directory or sent through this channel__, as all subjects share the same download webdav user.
- If you do not have a server, or if the connection cannot be established, you can choose to send data via e-mail as back-up. It is advisable to use this option only with encryption enabled. The e-mail itself will be unencrypted, and the encrypted files will be attached.
- This application was designed to be used on __specific, monitored devices__ that are in the possession of the respective participants at all times and are distributed upon request. __It was not designed to be distributed through an app store.__ It is advisable to connect the devices to a remote-management service in order to manage permissions and to lock or reset them in case of reported misuse. Participants can also set an iOS passcode for an additional layer of safety.

## Device connection
The `DataController` manages incoming data from the employed `DataSource` and has access to device-information like battery and sampling rate. Interfacing with a particular device is realized with in a separate controller that conforms to the `DataSource` protocol. At the time of creation, two data sources were included: The `MuseDelegate`, that interfaces with the Muse (2016) EEG headset by InteraXon, and the `OscillatorDelegate`, which is a dummy source that creates random oscillations for testing without the need for external hardware. `data`, `timestamp`, and `deviceStateChanged` are the main variables that can be observed by other functions.

## Processing
The `ProcessingDelegate` is instantiated during EEG recording. It observes the `data` signal from the `DataController`, and emits `avgSignalQuality` and band-power. 

Signal quality (0 - 100%) can be computed in two ways. Please review the references on the main page for more details on these computations:
- in `signalQuality` mode, signal quality is defined by the variance of a moving, weighted average of the raw signal.
- in `noiseDetection` mode, signal quality is defined by the amount of 50Hz noise in the raw signal. This is used to help subjects find a location with little electromagnetic interference. This mode also computes the full real-time EEG band-power spectrum that is emitted through `spectrum`. This is only used in developer-mode raw data display during hardware preparation. This computation is handled by the `FFTDelegate`.

## Recording
The `RecordingDelegate` is instantiated during EEG recording. It observes the `data` signal from the `DataController` and stores values in a `EEGRecording` object. `markerData` and `paradigm` are collected from the `ScenarioViewController` during recording. Additional `subjectInfo`, like fitting time, is collected during recording. The variable `trialInfo`, unused for now, can be utilized to store information per trial, like a score. 

## Storage
A dictionary-array in user-defaults is used to keep track of recorded data. The corresponding objects are defined in the `DataModel`. The `StorageController` stores files to the document directory of the application, optionally with encryption. All storage functions return an index at which the `DataModel` representation for this file was stored in user-defaults. This representation is the only way to retrieve, manipulate, transmit, or delete the stored file. Storage occurs right after the subject completes the corresponding task.
- to store a recording, the `EEGRecording` object from the `RecordingDelegate` is passed. The storage controller prepares an *HDF5* file with this information and stores it (see [structures](./placeholders.md) for more information).
- to store a questionnaire, a `String:Any` dictionary is passed and stored as JSON.
- to store the Consent PDF the *ResearchKit* object `ORKTaskResult` is passed at the end of the boarding procedure, together with the `StudyModel` object of the boarded study. The PDF is regenerated from the steps defined in `StudyModel->consent` and the signature is applied to it. It is then stored.

## Transmission
Transmission is handled by the `TransferController` via webdav or e-mail (optional). It occurs automatically after storing data (can be changed in `Setup`). A visual representation of the upload progress is given with the `UploadViewController` after the subject completed a questionnaire or a recording. The `uploadpending` function can be called at any time to transfer pending items. The `DataModel` for each file contains a `transmission` flag that is set to true if transmission was successful. See the "Safety measures" for additional details. 

### Copying files manually
If you need to copy individual files off the device, enable developer-mode and navigate to HomeView->Settings->Recorded Data. You will see a list of files that were recorded on this device. Swiping on the respective tableview cell enables sharing via iOS action sheet (leading action) or deletion (trailing action). 

## Announcements
A global announcement can be placed as a JSON file in the root directory of an optional download webdav. If the JSON in this location is newer than the lastly downloaded message, it is downloaded by `TransferController` and displayed in `HomeViewController` when the subject starts the next scenario. An announcement can also be located in a folder that is named like the UUID of a user. Make sure that only public information is stored in this directory or sent through this channel. `supplementals/message.json` contains an example message. The content of the message is processed by `BannerController`.

