clc;
clear;
matlab_config;

cd(projectPath); 

% Add this project to the path
addpath(genpath('./'));

% Save logs
diary(strcat(datasetPath, '\log_stage_2.txt'));

% Turn off fieldTrip warning messages
ft_warning off;

% Configuration struct used by FieldTrip
cfg = [];
cfg.subjectName = subjectName;
cfg.dataset  = datasetPath;                            %  Taken from the configuration file loaded above
cfg.trialfun = 'stage_1_trialfun';                     %  function used to split the dataset
cfg.trialdef.numtrain    = 20;                         %  No. of trials to be used as train set, just a required parameter give it some value
cfg.trialdef.eventtype   = 'trigger';                  %  Type of event used
cfg.trialdef.eventvalue1 = 128;                        %  TTL Pulse of Class 1, Left in our case
cfg.trialdef.eventvalue2 = 192;                        %  TTL Pulse of Class 2, Right in our case
cfg.trialdef.prestim     = 0.1;                        %  time in s, Values before TTL pulse to be considered
cfg.trialdef.poststim    = 4.0;                        %  time in s, length of each trial
cfg.freq                 = [4 250];                    %  Bandpass frequencies [4 250]

% Configuration files needed to get overlapping trials during training
re_cfg = [];
re_cfg.length  = 1;       % Length of each trial in s
re_cfg.overlap = 0.96875;  % Since we want an output every 1/16th of a second, 0.96875 for every 1/32th of a second

cfg.viz_csp_weights = true;
cfg.multifold = true;  % Perform a 10 fold corss validation
cfg.n_folds = 10;

% Start training an SVM and saves it
% research_train_csp_svm(cfg, re_cfg);
train_csp_svm(cfg, re_cfg);
