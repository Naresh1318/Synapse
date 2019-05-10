clc;
clear;
matlab_config;

% Add this project to the path
cd(projectPath);
addpath(genpath('./'));

% Save logs
diary(strcat(datasetPath, '\log_stage_3_stream.txt'));

% Make record poll directory
mkdir(strcat(datasetPath, '\record_pool'));

% Configuration needed by FieldTrip
cfg = [];

cfg.recordPoolPath = strcat(datasetPath, '\record_pool');

% System ID or IP Address of the acquisition machine
cfg.acquisition = serverName;

% NOTE: Since this script tries to stream all the available channels,
% ensure that you modify the configuration file in Pegasus to stream only
% the desired channels. This is a little easier to do than to specify all
% the channel names here.
cfg.channel = 'all';

% Write data here
cfg.target.datafile = 'buffer://localhost:1972';

% Start Acquisition
realtime_neuralynx_acquisition(cfg);
