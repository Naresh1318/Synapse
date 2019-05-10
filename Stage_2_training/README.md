## Stage\_2: Training

This stage uses the ECoG data and events file to train a classifier. Since this process is computation heavy, it is recommended that this be performed on a PC with that has a Xeon or any i7 or i9 processor. The minimum RAM required is 16GB but 64GB is recommended. We will be performing training using the Acquisition machine as it meets the minimum requirements. Follow the steps below to get the trained model:



### Checks
* Get the path of the data directory.  Pegasus > Acquisition > Recording Options > Data Directory 

  * Have a look at the **Running** section and change the `datasetPath` variable.

* You just need the directory name, not a specific file that was created. 

  * Ex: `C:/Pegasus/Dataset/Subject01`

* Running training does not require Pegasus to be running. But, since we need a lot of computation power to finish training, it is recommended that the recording and acquisition has been turned off. 

* Ensure that you have the ECoG data from the previous stage stored in the required directory.

* Run Matlab on the Acquisition machine and move to the Stage\_2 directory.

  ​



### Running

The code for running Stage\_2 is present in:

*  `start_training.m` : Contains the experimental parameters that need to be modified before running it.

  | Parameter                | Description                              |
  | ------------------------ | ---------------------------------------- |
  | datasetPath              | Path that contains the ECoG data to be trained on. |
  | cfg.trialdef.numtrain    | No. of training trials                   |
  | cfg.trialdef.eventvalue1 | TTL value of class 1 (eg. left or right) |
  | cfg.trialdef.eventvalue2 | TTL value of class 2 (eg. left or right) |
  | cfg.trialdef.prestim     | Time in s that which indicated the prestim values to consider. |
  | cfg.overlap              |                                          |
  | cfg.trialLength          |                                          |

* `train_svm.m`: Contains code to train an SVM. *Do not modify this unless you know what you are doing.*

***Note:*** 

* Based on the number of trials performed and the specs of the PC used the training process can take at least 2 mins.

  ​



### Outcome

* A trained classifier with its parameters saved in the main project directory (`./ECoG_BCI`). - > `trained_svm.mat`
* The dataset that is saved as `train_dat.mat` is preprocessed with baseline correction, bandpass filtering and any other technique used.