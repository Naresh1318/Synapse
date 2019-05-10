function research_train_csp_svm(cfg, re_cfg)
% Train a realtime application for online
% classification of the data. It should work both for EEG and MEG.
% This version uses different trials for testing.
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

segments_per_trial = ceil((cfg.trialdef.poststim + cfg.trialdef.prestim - re_cfg.length) / (1-re_cfg.overlap));
trial_start_indices = 1:segments_per_trial:size(labels, 1);
trial_left_indices = [];
trial_right_indices = [];

for i=1:size(trial_classes, 1)
    if trial_classes(i, 1) == 2
        trial_right_indices = [trial_right_indices; trial_start_indices(1, i)];
    else
        trial_left_indices = [trial_left_indices; trial_start_indices(1, i)];
    end
end

for fold=1:n_folds
    right_indices = randperm(size(trial_right_indices, 1));
    left_indices = randperm(size(trial_left_indices, 1));
    
    test_start_indices = [trial_left_indices(left_indices(1:2), 1); trial_right_indices(right_indices(1:2), 1)];
    test_indices = [];
    for i=1:size(test_start_indices)
        idx = test_start_indices(i, 1):test_start_indices(i, 1)+segments_per_trial-1;
        test_indices = [test_indices; idx];
    end
    
    train_start_indices = [trial_left_indices(left_indices(3:end)); trial_right_indices(right_indices(3:end))];
    train_indices = [];
    for i=1:size(train_start_indices)
        idx = train_start_indices(i, 1):train_start_indices(i, 1)+segments_per_trial-1;
        train_indices = [train_indices; idx];
    end

    train_X = train_dat(train_indices, :);
    train_Y = labels(train_indices, :);
    test_X = train_dat(test_indices, :);
    test_Y = labels(test_indices, :);
    
    rand_indices = randperm(size(train_X, 1));
    train_X = train_X(rand_indices, :);
    train_Y = train_Y(rand_indices, :);
    
    rand_indices = randperm(size(test_X, 1));
    test_X = test_X(rand_indices, :);
    test_Y = test_Y(rand_indices, :);
    
    % Find CSP filters
    class_dat = {};
    n_unique_classes = size(unique(train_Y), 1);
    for i=1:n_unique_classes
        class_dat{i} = train_X(train_Y==i-1, :);
        class_dat{i} = reshape(class_dat{i}, [size(class_dat{i}, 1), nchan, re_cfg.length*cfg.hdr.Fs]);
    end

    fprintf('Finding CSP filters...\n');
    w = find_csp(class_dat);
    train_X = apply_filter([class_dat{1}; class_dat{2}], w, 2);
    train_Y = [zeros(size(class_dat{1}, 1), 1); ones(size(class_dat{2}, 1), 1)];

    % Preprocess test data using filter learnt from trian data
    test_X = reshape(test_X, [size(test_X, 1), nchan, re_cfg.length*cfg.hdr.Fs]);
    test_X = apply_filter(test_X, w, 2);

    % Shuffe train data
    rand_indices = randperm(size(train_X, 1));
    train_X = train_X(rand_indices, :);
    train_Y = train_Y(rand_indices, :);

    % Save dataset
    if cfg.multifold == false
        save(strcat(cfg.dataset, '\train_class_dat.mat'), 'class_dat', '-v7.3');
        save(strcat(cfg.dataset, '\csp_train_x.mat'), 'train_X', '-v7.3');
        save(strcat(cfg.dataset, '\csp_train_y.mat'), 'train_Y');
        save(strcat(cfg.dataset, '\csp_test_x.mat'), 'test_X', '-v7.3');
        save(strcat(cfg.dataset, '\csp_test_y.mat'), 'test_Y');
    end

    [SVMModel, FitInfo] = fitclinear(train_X, train_Y, 'Verbose', 0);
    % disp(FitInfo);

    % Training Accuracy
    estimate = predict(SVMModel, train_X);
    pred = (estimate==train_Y);
    accuracy = mean(pred)*100;
    train_accs(fold, 1) = accuracy;
    fprintf('Fold: %d \t Training Accuracy: %f\n', fold, accuracy);

    % Testing Accuracy
    estimate = predict(SVMModel, test_X);
    pred = (estimate==test_Y);
    accuracy = mean(pred)*100;
    test_accs(fold, 1) = accuracy;
    fprintf('Fold: %d \t Testing Accuracy: %f\n\n\n', fold, accuracy);
    
    Hit = [];
    Trial = [];
    Trial_sum = [];
    Total_trial = [];
    Trial_accuracy = [];
    Trial_hit = [];
    Target = [];
    targets_hit = 0;
    rights_hit = 0;
    total_rights = 0;
    required_trial_sum = 28;
    test_X = train_dat(test_indices, :);
    test_Y = labels(test_indices, :);
    for i=1:size(test_indices, 1)        
        trial_sum = 0;
        total_trials = 0;
        target_hit = false;
        trial_idxs = test_indices(i, :);
        for j=1:size(trial_idxs, 2)
            idx = trial_idxs(j);
            current_data = train_dat(idx, :);
            current_data = reshape(current_data, [1, nchan, re_cfg.length*cfg.hdr.Fs]);
            current_data = apply_filter(current_data, w, 2);
            estimation = predict(SVMModel, current_data);
            target = labels(idx);
            
            if estimation == target
                trial_sum = trial_sum + 1;
            else
                trial_sum = trial_sum - 1;
            end
            
            total_trials = total_trials + 1;
            trial_acc = trial_sum / total_trials;
            if abs(trial_sum) >= required_trial_sum
                if trial_sum > 0
                    targets_hit = targets_hit + 1;
                    target_hit = true;
                    if target == 1
                       rights_hit = rights_hit + 1; 
                       total_rights = total_rights + 1;
                    end
                end
                break;
            end
        end
        
        if target_hit ~= true && target == 1
           total_rights = total_rights + 1;
        end
        
        Trial = [Trial; i];
        Trial_sum = [Trial_sum; trial_sum];
        Total_trial = [Total_trial; total_trials];
        Trial_accuracy = [Trial_accuracy; trial_acc];
        Target = [Target; target];
        
        if trial_sum >= required_trial_sum
            Hit = [Hit; target];
        elseif trial_sum <= -required_trial_sum
            Hit = [Hit; abs(target - 1)];
        else
            Hit = [Hit; -1];
        end
    end
    
    summary = table(Trial, Trial_sum, Total_trial, Trial_accuracy, Target, Hit);
    disp(summary);
    
    % Display stat
    correct_misses = sum(summary.Target == -1 & summary.Hit == -1);
    n_misses = sum(summary.Hit == -1);
    n_hits = sum(summary.Target == summary.Hit);
    fprintf('\n\nTotal Trials: %d \t #Rights: %d \t #Left: %d\n', Trial(end), total_rights, Trial(end) - total_rights);
    fprintf('#Hits: %d \t #Right Hits: %d \t #Left Hits: %d \t #Misses: %d\n', n_hits, rights_hit, n_hits-rights_hit-correct_misses, correct_misses);
    fprintf('Average accuracy: %f\n\n\n', mean(summary.Trial_accuracy));
    fprintf('All rights: %d \t All Lefts: %d \n', sum(summary.Hit == 1), sum(summary.Hit == 0));
end

avg_train_acc = mean(train_accs);
std_train_acc = std(train_accs);
avg_test_acc = mean(test_accs);
std_test_acc = std(test_accs);

fprintf('\n%d Fold Train Accuracy: %f +- %f\n', fold, avg_train_acc, std_train_acc);
fprintf('%d Fold Test Accuracy: %f +- %f\n', fold, avg_test_acc, std_test_acc);

% Save the trained model in the subject directory
save(strcat(cfg.dataset, '\hdr.mat'), 'hdr');
save(strcat(cfg.dataset, '\csp_weights.mat'), 'w', '-v7.3');
save(strcat(cfg.dataset, '\trained_svm.mat'), 'SVMModel', '-v7.3');

if (cfg.viz_csp_weights)
    visualize_csp_weights(w, hdr, cfg.subjectName);
end


