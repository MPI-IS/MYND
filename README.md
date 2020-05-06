![logo](./header.jpg)

# MYND: Neuroscience at Home
MYND is a framework that allows for easy, self-supervised, at-home participation in large-scale, multi-day neurophysiological recordings. It was originally designed to help with the unsupervised evaluation of control strategies for brain-computer interfaces under realistic conditions.

## Motivation
Using thoughts to interact with our surroundings through brain-computer interfaces (BCIs) could be the next frontier of personal and medical technology. However, research in this area is still stuck with laboratory equipment in controlled environments. This makes it hard to translate conceptual systems into the realistic context in which they ultimately need to function. MYND was developed to tackle this limitation. The goal of this platform is to provide a tool that lets subjects easily evaluate conceptual BCIs and participate in large-scale neurophysiological studies at home, without expert supervision. See reference (1) for more details.

## Versions
Scientific supervision of this project was provided by Prof. Dr. Moritz Grosse-Wentrup, University of Vienna, and Prof. Dr. Bernhard Schölkopf, Max Planck Institute for Intelligent Systems.

### [iOS](./iOS)
This version was developed by Matthias Hohmann as part of a research project on large-scale neuroscientific experiments at the Max Planck Institute for Intelligent Systems, Tübingen, Germany. Assistance was provided by Raffi Enficiaud, Talha Zaman, Michelle Hackl and Brian Wirth. 

This version features 1) the ability to connect to a consumer-grade EEG (currently the Muse EEG headband), 2) fit the headset by using a real-time feedback algorithm on signal quality, 3) record questionnaire or neurophysiological data in multi-day studies, with a flexible timeout mechanism, 4) transfer the data to a server with asymmetric encryption, 5) data storage in widely-used HDF5 and JSON formats, 6) abstracted signal processing through observer-patterns, 7) localization. Documentation and starting points to assist with likely future developments are presented in [docs](./iOS/docs/index.md).

### [Android](./Android)
This version was developed by Brian Wirth as part of a summer internship at the Max Planck Institute for Intelligent Systems, Tübingen, Germany. Assistance was provided by Michelle Hackl and Matthias Hohmann. 

This version features 1) the ability to connect to a consumer-grade EEG (currently the Muse EEG headband), 2) fit the headset by using a real-time feedback algorithm on signal quality, 3) record neurophysiological data, 4) transfer the data to a server, 5) data storage in widely-used CSV, 6) abstracted signal processing through observer-patterns.

### Qt C++
This version was developed by Talha Zaman and Raffi Enficiaud as part of their work at the Software Workshop of the Max Planck Institute for Intelligent Systems, Tübingen, Germany. Matthias Hohmann assisted with the development. Further assistance was provided by Lukas Grossberger, Christian Förster, and Robert Hildebrandt.

*TBA*

## Scientific Publications using MYND
1. Hohmann, M. R., Konieczny, L., Hackl, M., Wirth, B., Zaman, T., Enficiaud, R., Grosse-Wentrup, M., & Schölkopf, B. (2020). MYND: Unsupervised Evaluation of Novel BCI Control Strategies on Consumer Hardware. http://arxiv.org/abs/2002.11754

2. Hohmann, M. R., Hackl, M., Wirth, B., Zaman, T., Enficiaud, R., Grosse-Wentrup, M., & Schölkopf, B. (2019). MYND: A Platform for Large-scale Neuroscientific Studies. In Extended Abstracts of the 2019 CHI Conference on Human Factors in Computing Systems (pp. 1–6). ACM Press. https://doi.org/10.1145/3290607.3313002

3. Hohmann, M., Hackl, M., Wirth, B., Zaman, T., Enficiaud, R., Grosse-Wentrup, M., & Schölkopf, B. (2019). Forschung mit allen: Eine Smartphone App zur Teilnahme an neurowissenschaftlicher Grundlagenforschung in ALS. Nervenheilkunde, 38(05), P22. https://doi.org/10.1055/s-0039-1685040

## License
Details about the license of this project can be found [here](./LICENSE.md). For other
licensing options please contact Max-Planck-Innovation (info@max-planck-innovation.de) with the reference `MI 0104-5982-BC-JK`.

## Documentation
Please have a look at the individual README files of each sub-project for more information.

