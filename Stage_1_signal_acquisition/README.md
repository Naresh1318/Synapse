## Stage\_1: Signal Acquisition

This folder contains scripts to acquire data  and save it on the acquisition machine (Neuralynx machine hooked up to the amplifier) with the presentation performed by the, well, presentation machine.



### Checks

* Run MATLAB and change its priority to runtime using the task manager.

* Always run the experiments on the primary monitor.

* Before starting, ensure that both of the machines are connected to the ethernet hub by performing a ping on one of the machines.  Also note down the IP Address of both the machines.

* This must later be followed by a quick check of the TTL pulse generator connections to both the presentation machine and the Neuralynx amplifier.

* Ensure that the Acquisition machine has Pegasus running and that acquisition and recording are turned off.

* Enable raw file recording on Pegasus.

* Downsample by a factor of 10 (for 3200 Hz) or 16 (for 2000 Hz).

  Acquisition Entities and Display Properties Window > Acquisition Entities > CSC (Select all channels) > Sub Sampling Interleave = 10 or 16.

* Ensure that you have the `System ID` (on the acquisition System Status Window) noted down, it will be used in the `start_acquistion.m` for the variable `serverName`.

* Run Matlab on the presentation machine and move to the Stage\_1 directory. 

  * Ex: If the ECoG BCI folder is in C:/, then `cd C:/ECoG_BCI/`
  * Do ***NOT*** cd to any other director when running any of the stages. Stay in the main project directory.

* Have a look at the properties given below. They can be tuned based on the experiment you wish to perform.

* Execute the script `start_acquistion.m`

  ​

***Note:***  

* You can get the IP address for the machine connected to the ethernet hub by running the `ipconfig` command on the command prompt and looking at the Ethernet section.

* If you want to skip the rest class, then just remove it from the classes list.

* You DO NOT have to start/stop recording on the Pegasus software, the script takes care of this! You're welcome!

  ​

### Running

The code for running the presentation is on the `start_acquisition.m` file. This must be run on the presentation machine. Follow the steps below to change some parameters in the script before running it:

| BCI presentation parameters         | Description                                                  |
| :---------------------------------- | :----------------------------------------------------------- |
| n_baselines = 2                     | Initial trials which are generally ignored                   |
| n_trials = 2                        | No. of trials for each class                                 |
| time_inst                           | time in s to show instructions                               |
| time_rest_init = 30                 | time in s that the participant rests                         |
| time_rest_start = 2                 | time in s between the setup and class pulse                  |
| time_trial = 4                      | time in s for each trial                                     |
| time_rest_after = 3                 | time in s after each trial, the user is expected to rest     |
| classes = {'rest', 'left', 'right'} | class names                                                  |
| serverName = 'LAPTOP-M2KNU8QN'      | name/IP of the server that has Pegasus or the Netcom router IP running |



### Outcome

After running through the presentation, the ECoG data will be stored in the Acquisition machine.
