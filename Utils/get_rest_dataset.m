clc;
clear;

datasetPath = 'D:\Projects\ECoG_BCI\Data\2018-10-20_20-35-51_Stage_1';
projectPath = 'D:\Projects\ECoG_BCI';

cd(projectPath);

% Add this project to the path
addpath(genpath('./'));

% Turn off fieldTrip warning messages
ft_warning off

% Configuration struct used by FieldTrip
cfg = [];
cfg.dataset  = datasetPath;                            %  Taken from the configuration file loaded above
cfg.trialfun = 'ft_trialfun_twoclass_classification';  %  function used to split the dataset
cfg.trialdef.numtrain    = 20;                         %  No. of trials to be used as train set, just a required parameter give it some value
cfg.trialdef.eventtype   = 'trigger';                  %  Type of event used
cfg.trialdef.eventvalue1 = 128;                        %  TTL Pulse of Class 1, Left in our case
cfg.trialdef.eventvalue2 = 192;                        %  TTL Pulse of Class 2, Right in our case
cfg.trialdef.prestim     = 0.1;                        %  time in s, Values before TTL pulse to be considered
cfg.trialdef.poststim    = 4.0;                        %  time in s, length of each trial
cfg.freq                 = [4 250];                    %  Bandpass frequencies

% Use this for rest
% cfg = [];
% cfg.dataset  = datasetPath;                            %  Taken from the configuration file loaded above
% cfg.trialfun = 'ft_trialfun_general';                  %  function used to split the dataset
% cfg.trialdef.numtrain    = 40;                         %  No. of trials to be used as train set, just a required parameter give it some value
% cfg.trialdef.eventtype   = 'trigger';                  %  Type of event used
% cfg.trialdef.eventvalue  = 64;                        %  TTL Pulse of Class 1, Left in our case
% cfg.trialdef.prestim     = 0.1;                        %  time in s, Values before TTL pulse to be considered
% cfg.trialdef.poststim    = 2.0;                        %  time in s, length of each trial
% cfg.freq                 = [4 250];                    %  Bandpass frequencies

% Configuration files needed to get overlapping trials during training
re_cfg = [];
re_cfg.length  = 1;       % Length of each trial in s
re_cfg.overlap = 0.9375;  % Since we want an output every 1/16th of a second


% Set the default configuration options
if ~isfield(cfg, 'dataformat'),     cfg.dataformat = [];      end % default is detected automatically
if ~isfield(cfg, 'headerformat'),   cfg.headerformat = [];    end % default is detected automatically
if ~isfield(cfg, 'eventformat'),    cfg.eventformat = [];     end % default is detected automatically
if ~isfield(cfg, 'channel'),        cfg.channel = 'all';      end
if ~isfield(cfg, 'bufferdata'),     cfg.bufferdata = 'last';  end % first or last

% Translate dataset into datafile+headerfile
cfg = ft_checkconfig(cfg, 'dataset2files', 'yes');
cfg = ft_checkconfig(cfg, 'required', {'datafile' 'headerfile'});

% Ensure that the persistent variables related to caching are cleared
clear ft_read_header
% Start by reading the header from the realtime buffer
hdr = ft_read_header(cfg.headerfile, 'cache', true);

% Define a subset of channels for reading
cfg.channel = ft_channelselection(cfg.channel, hdr.label);
chanindx    = match_str(hdr.label, cfg.channel);
nchan       = length(chanindx);

if nchan==0
  ft_error('no channels were selected');
end

% These are for the data handling
prevSample = 0;

% Determine latest header and event information
event     = ft_read_event(cfg.dataset, 'minsample', prevSample+1);  % only consider events that are later than the data processed sofar
hdr       = ft_read_header(cfg.dataset, 'cache', true);             % the trialfun might want to use this, but it is not required
cfg.event = event;                                                  % store it in the configuration, so that it can be passed on to the trialfun
cfg.hdr   = hdr;                                                    % store it in the configuration, so that it can be passed on to the trialfun

% Evaluate the trialfun, note that the trialfun should not re-read the events and header
fprintf('evaluating ''%s'' based on %d events\n', cfg.trialfun, length(event));

cfg = ft_definetrial(cfg); 

% Remove the trl rows with NaN class
class_1 = cfg.trl(:, 4) == 1;
class_2 = cfg.trl(:, 4) == 2;
required_classes = class_1 | class_2;
cfg.trl = cfg.trl(required_classes, :);

% Use this for rest
% classes = cfg.trl(:, 4) == 64;
% cfg.trl = cfg.trl(classes, :);

% Preprocess the dataset
fprintf('Reading data...\n');
data = ft_preprocessing(cfg);  % This step does not perform any preprocessing. It just reads files from disk and segments them

% Segment and get overlapping data chunks
fprintf('Segmenting data...\n');
data = ft_redefinetrial(re_cfg, data);

% Update the trl to incorporate the new data chunks
trl = data.cfg.trl;

% The code below assumes that the 4th column of the trl matrix contains
% the class label and the 5th column a boolean indicating whether it is a
% training set item or test set item
if size(trl,2)<4
  trl(:,4) = nan;  % don't asign a default class
end
if size(trl,2)<5
  trl(:,5) = 0;    % assume that it is a test set item
end

% Apply baseline correction, preprocess each data chunk and prepare dataset
fprintf('Processing %d trials\n', size(trl,1));
fprintf('Preparing dataset..\n');
train_dat = zeros(size(trl, 1), nchan*re_cfg.length*cfg.hdr.Fs);
train_class = zeros(size(trl, 1), 1);
for trllop=1:size(trl, 1)
    class = trl(trllop,4);
    if isnan(class)
        continue
    end

    % Read data segment from buffer
    dat = data.trial;
    dat = dat{trllop};
    
    % Apply some preprocessing options
    dat = ft_preproc_baselinecorrect(dat);
    
    [dat] = ft_preproc_bandpassfilter(dat, hdr.Fs, cfg.freq, 3);

    % Add the current trial to the training data
    [nchan, nsmp] = size(dat);
    
    % Convert matrix to a vector
    dat = reshape(dat, [1, nchan*nsmp]);
    train_dat(trllop, :) = dat;
    train_class(trllop, :) = class;
    
    % Progress
    if mod(trllop, 100) == 0
        fprintf('Setting up data: %d/%d\n', trllop, size(trl,1));
    end
    
end % looping over new trials

% Train an SVM
labels = train_class - 1;

% Save model and dataset
class_0 = train_dat(labels==0, :);
class_1 = train_dat(labels==1, :);
save(strcat(cfg.dataset, '\car11_class_0.mat'), 'class_0', '-v7.3');
save(strcat(cfg.dataset, '\car11_class_1.mat'), 'class_1', '-v7.3');

% Use this for rest
% save(strcat(cfg.dataset, '\car05_rest.mat'), 'train_dat', '-v7.3');

fprintf('Data Saved!\n');
