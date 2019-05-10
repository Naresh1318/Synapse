function train_svm_new_csp(cfg, re_cfg)

% Train a realtime application for online
% classification of the data. It should work both for EEG and MEG.
%
% Use as
%   ft_realtime_classification(cfg)
% with the following configuration options
%   cfg.channel    = cell-array, see FT_CHANNELSELECTION (default = 'all')
%   cfg.trialfun   = string with the trial function
%
% The source of the data is configured as
%   cfg.dataset       = string
% or alternatively to obtain more low-level control as
%   cfg.datafile      = string
%   cfg.headerfile    = string
%   cfg.eventfile     = string
%   cfg.dataformat    = string, default is determined automatic
%   cfg.headerformat  = string, default is determined automatic
%   cfg.eventformat   = string, default is determined automatic
%
% This function works with two-class data that is timelocked to a trigger.
% Data selection is based on events that should be present in the
% datastream or datafile. The user should specify a trial function that
% selects pieces of data to be classified, or pieces of data on which the
% classifier has to be trained.The trialfun should return segments in a
% trial definition (see FT_DEFINETRIAL). The 4th column of the trl matrix
% should contain the class label (number 1 or 2). The 5th colum of the trl
% matrix should contain a flag indicating whether it belongs to the test or
% to the training set (0 or 1 respectively).
%
% Example useage:
%   cfg = [];
%   cfg.dataset  = 'Subject01.ds';
%   cfg.trialfun = 'trialfun_Subject01';
%   ft_realtime_classification(cfg);
%
% To stop the realtime function, you have to press Ctrl-C

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

trial_classes = cfg.trl(:, 4);

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

fprintf('Training SVM...\n');

% Train an SVM
labels = train_class - 1;

% % Save model and dataset
% save(strcat(cfg.dataset, '\train_dat.mat'), 'train_dat', '-v7.3');
% save(strcat(cfg.dataset, '\train_class.mat'), 'train_class');

if cfg.multifold == true
	n_folds = cfg.n_folds;
else
	n_folds = 1;
end

train_accs = zeros(n_folds, 1);
test_accs = zeros(n_folds, 1);

trial_start_indices = 1:99:2574;
trial_left_indices = [];
trial_right_indices = [];

for i=1:size(trial_classes, 1)
    if trial_classes(i, 1) == 2
        trial_right_indices = [trial_right_indices; trial_start_indices(1, i)];
    else
        trial_left_indices = [trial_left_indices; trial_start_indices(1, i)];
    end
end

% Train parameters
proc.train= {{'CSPW', @proc_cspAuto, 3}
             {@proc_variance}
             {@proc_logarithm}
            };
proc.apply= {{@proc_linearDerivation, '$CSPW'}
             {@proc_variance}
             {@proc_logarithm}
            };

ClassifierFcn = {@train_RLDAshrink, 'Gamma', 1};
applyFcn= misc_getApplyFunc(ClassifierFcn);
[trainFcn, trainPar]= misc_getFuncParam(ClassifierFcn);

for fold=1:n_folds
    right_indices = randperm(size(trial_right_indices, 1));
    left_indices = randperm(size(trial_left_indices, 1));
    
    test_start_indices = [trial_left_indices(left_indices(1:2), 1); trial_right_indices(right_indices(1:2), 1)];
    test_indices = [];
    for i=1:size(test_start_indices)
        idx = test_start_indices(i, 1):test_start_indices(i, 1)+98;
        test_indices = [test_indices, idx];
    end
    
    train_start_indices = [trial_left_indices(left_indices(3:end)); trial_right_indices(right_indices(3:end))];
    train_indices = [];
    for i=1:size(train_start_indices)
        idx = train_start_indices(i, 1):train_start_indices(i, 1)+98;
        train_indices = [train_indices; idx];
    end

    train_X = train_dat(train_indices, :);
    train_Y = labels(train_indices, :);
    test_X = train_dat(test_indices, :);
    test_Y = labels(test_indices, :);
    
    rand_indices = randperm(size(train_X, 1));
    train_X = train_X(rand_indices, :);
    train_X = reshape(train_X, [size(train_X, 1), nchan, re_cfg.length*cfg.hdr.Fs]);
    train_Y = train_Y(rand_indices, :);
    train_Y = one_hot(train_Y);
    
    rand_indices = randperm(size(test_X, 1));
    test_X = test_X(rand_indices, :);
    test_X = reshape(test_X, [size(test_X, 1), nchan, re_cfg.length*cfg.hdr.Fs]);
    test_Y = test_Y(rand_indices, :);
    test_Y = one_hot(test_Y);

    fvTr = {};
    fvTr.x = permute(train_X, [3, 2, 1]);
    fvTr.y = train_Y;
    fvTr.fs = 2000;
    fvTr.clab = {};

    fvTe = {};
    fvTe.x = permute(test_X, [3, 2, 1]);
    fvTe.y = test_Y;
    fvTe.fs = 2000;
    fvTe.clab = {};
    
    [fvTr, memo] = xvalutil_proc(fvTr, proc.train);
    xsz = size(fvTr.x);
    fvsz = [prod(xsz(1:end-1)) xsz(end)];
    C = trainFcn(reshape(fvTr.x,fvsz), fvTr.y, trainPar{:});

    fvTe = xvalutil_proc(fvTe, proc.apply, memo);
    xsz = size(fvTe.x);
    out = applyFcn(C, reshape(fvTe.x, [prod(xsz(1:end-1)) xsz(end)]));
    outTr = applyFcn(C, reshape(fvTr.x, fvsz));
    
    est= 1.5 + 0.5*sign(outTr);
    lind= [1:size(train_Y,1)]*train_Y;
    accuracy = mean(est == lind) * 100;
    train_accs(fold, 1) = accuracy;
    fprintf('Fold: %d \t Training Accuracy: %f\n', fold, accuracy);
    
    est= 1.5 + 0.5*sign(out);
    lind= [1:size(test_Y,1)]*test_Y;
    accuracy = mean(est == lind) * 100;
    test_accs(fold, 1) = accuracy;
    fprintf('Fold: %d \t Testing Accuracy: %f\n\n\n', fold, accuracy);
end

avg_train_acc = mean(train_accs);
std_train_acc = std(train_accs);
avg_test_acc = mean(test_accs);
std_test_acc = std(test_accs);

fprintf('\n%d Fold Train Accuracy: %f +- %f\n', fold, avg_train_acc, std_train_acc);
fprintf('%d Fold Test Accuracy: %f +- %f\n', fold, avg_test_acc, std_test_acc);
