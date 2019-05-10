# Synapse

<p align=center>
<img src="https://raw.githubusercontent.com/Naresh1318/Synapse/master/README/icon.png" width=300 />
</p>

Synapse is designed to allow BCI experiments to be performed using MATLAB and Python. It currently only supports amplifiers provided by Neuralynx with the option to easily add other amplifiers if needed.


### Requirements

* MATLAB (tested on 2018b):
  * *Packages*:
    * [Psychtoolbox](http://psychtoolbox.org/)
    * [Matlab LSL](https://github.com/sccn/labstreaminglayer)
    * [NetCom Development Package](https://neuralynx.com/software/netcom-development-package)
    * [Statistics and Machine Learning Toolbox](https://www.mathworks.com/products/statistics.html)
* Python 3.5 or newer:
  * *Packages*:
    * [mne](https://www.martinos.org/mne/stable/index.html)
    * [numpy](http://www.numpy.org/)
    * [matplotlib](https://matplotlib.org/)

***Note***: 

* Python packages can be installed using the following command `pip install -r requirements.txt`.
* Install these on both the acquisition and presentation machines.



This experiment required at least two workstations and two monitors to get the job done. The connections to be made between them and their respective roles have been discussed next:

<p align=center>
<img src="https://raw.githubusercontent.com/Naresh1318/Synapse/master/README/hardware_setup.png" width=600 />
</p>



The first workstation, referred to as the Acquisition Machine, performs data collection and model training. The second workstation, known as the Presentation Machine, is responsible for running the presentation and performing the online BCI task using the trained model.

As can be seen from the folders present in the repository, the entire task is divided into 3 main stages:

1. *[Stage\_1](https://github.com/Naresh1318/ECoG_BCI/tree/master/Stage_1_signal_acquisition)*: This stage involves data collection used to train the classification model before performing the realtime BCI task. Here, the user is presented with arrows that indicate the imaginary movements to be performed. 

2. [Stage\_2](https://github.com/Naresh1318/ECoG_BCI/tree/master/Stage_2_training): This stage is mainly concerned with training the classification model using the data collected in the previous stage.

3. [Stage\_3](https://github.com/Naresh1318/ECoG_BCI/tree/master/Stage_3_online): This stage uses the trained model to perform the BCI task in realtime. 

   ***More details on these stages including the role of each of the machines can be found in their respective folder or by clicking on them.***​


