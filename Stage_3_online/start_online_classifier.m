clc;
clear;
matlab_config;

% Add this project to the path
cd(projectPath);
addpath(genpath('./'));

% Save logs
diary(strcat(datasetPath, '\log_stage_3_classifier.txt'));

% Configuration file needed by FieldTrip
cfg = [];

cfg.trialfun = 'ft_trialfun_twoclass_classification';
cfg.channel = 'all';
cfg.trialdef.eventvalue1 = 128;        %  Class 1 TTL pulse
cfg.trialdef.eventvalue2 = 192;        %  Class 2 TTL pulse
cfg.freq = [4 250];                    %  Bandpass filter frequencies

cfg.trail_length = 1;  % is s
cfg.overlap = 0.96875;  % 0.935 for 16 fps, 0.96875 for 32 fps

% Streamed data will be written at this location
cfg.dataset = 'buffer://localhost:1972';  

% Pegasus dataset path
cfg.datasetPath = datasetPath;

% Pegaus server from matlab config
cfg.serverName = serverName;

% Saved model path
cfg.modelPath = strcat(datasetPath, '\trained_svm.mat');

% Start online classifier
online_classifier(cfg);
