## Stage\_3: Online

This stage uses the trained model from Stage\_2 to classify the ECoG data in realtime. This stage requires both the presentation and the acquisition machine.



### Checks

- Ensure that Pegasus is up and running on the Acquisition machine.

- Ensure that the Presentation machine is connected to the ethernet hub and perform a ping to the Acquisition machine to confirm the connection.

- Start three instances of Matlab on the presentation machine. The first instance is used to start streaming the data to the Presentation machine and the second instance is used to perform realtime classification and the third one for stimulus display.

  ​



### Running

The code for running Stage\_3 is present in:

- `start_stream.m` : Contains parameters that is used to stream ECoG data from the Acquisition machine. ***Run this on the first Matlab instance after changing the required parameters***.

  | Parameter           | Description                              |
  | ------------------- | ---------------------------------------- |
  | cfg.acquisition     | Name/IP address on the Acquisition machine. |
  | cfg.channel         | Channels to stream, default: 'all'.      |
  | cfg.target.datafile | Address to write the data obtained from the Acquisition machine. default: 'buffer://localhost:1972'. |

- `start_online.m` :  Starts the online classification of the incoming ECoG data. ***Run this on the second instance of Matlab after running the previous script and changing the required parameters***. This starts classifying the incoming data and sends the results using an LSL stream.

  | Parameter                | Description                              |
  | ------------------------ | ---------------------------------------- |
  | cfg.dataset              | Address to read the data obtained from the Acquisition machine, default: 'buffer://localhost:1972'. |
  | cfg.channel              | Channels to stream, default: 'all'.      |
  | cfg.trialdef.eventvalue1 | TTL value of class 1 (eg. left or right). |
  | cfg.trialdef.eventvalue2 | TTL value of class 2 (eg. left or right). |

- `start_scenario.m`: Starts reading the LSL stream from the previous script and displays the online senario. ***Run this on the third instance of Matlab with the previous two running.*** You can change some of the default parameter if needed:

  | Parameters        | Description                                                  |
  | ----------------- | ------------------------------------------------------------ |
  | n_baselines       | No. of baseline runs. Must be a multiple of the number of class members, default: 2. |
  | n_trials          | No. of trails for each of the classes. default: 12.          |
  | time_instructions | Time in s, to show the instructions on the screen, default: 30. |
  | time_rest_init    | do nothing for _ s in the beginning, default: 1.             |
  | time_setup_start  | Time in s between the setup and show ball pulse, default: 2. |
  | time_ball_start   | Time in s between the ball pulse and paddle pulse, default: 2. |
  | time_paddle_start | Time in s between the paddle pulse and class pulse, default: 2. |
  | time_trial        | Time in s for each trail, default: 8.                        |
  | classes           | Class names, default: {'rest', 'left', 'right'}.             |
  | serverName        | Name/IP Address of the server that has Pegasus or Netcom router ip running. |


***Note:***

- Ensure that you run each of the scripts one after the other.

- Ensure that the IP address entered matches the Acquisition machine.

  ​



### Outcome

The subject controlling the cursor on the Presentation machine.