![screenshots](./screenshots.jpg)


## Features: For Subjects
MYND provides a user-interface that lets subjects:
- establish a connection with a consumer-grade EEG (currently the Muse EEG headband)
- fit the headset by using a real-time feedback algorithm on signal quality
- record questionnaire or neurophysiological data in multi-day studies, with a flexible timeout mechanism
- transfer the data to a server with asymmetric encryption

No internet connection required: data processing, storage, and experiment progression are managed on-device

## Features: For Scientists and Developers
Scientists and developers can easily extend the MYND application and use it to run large-scale studies:
- Abstracted signal processing through observer-patterns RxSwift: Specific hardware classes can be implemented without changing the processing pipeline. A generic oscillator function can be used to test the application without connecting hardware.
- Data storage in widely-used HDF5 and JSON formats, example files and a MATLAB load function can be found in `supplements`.
- Questionnaire sessions and steps for hardware preparation are defined in localized JSON files: Quick creation of multiple choice questionnaires and adaption to experimental needs and languages.

Some pointers for features that you may likely want to adapt were collected in the [documentation](./docs/index.md)

## Getting started
Please read the [documentation](./docs/index.md) once in it entirety before you use this application, to get an overview over the provided functionality, and possible starting points to adapt the application to your needs.

1. Check out this repo and use cocoapods to install dependencies. Make sure to review the [CREDITS](./CREDITS.md) for third-party licenses.
3. If you would like to use the app with the Muse 2016 EEG headband, get in touch with InteraXon at https://choosemuse.com/development/
4. Use `Setup.swift` to configure basic parameters for your needs, server addresses etc. 
5. Provide your own consent, questionnaires, subject information, and __encryption key__ by using the available templates
5. Compile and deploy! MYND was developed for iOS 12 with Swift 4.2.


## Credits
Check the [CREDITS](./CREDITS.md) for more information on used media, third-party licenses, and contributors.

