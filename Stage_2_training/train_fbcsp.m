function train_fbcsp(cfg, re_cfg)

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

fprintf('Training LDA ...\n');

% Convert label 1 to 0 and 2 to 1
labels = train_class - 1;

if cfg.multifold == true
	n_folds = cfg.n_folds;
else
	n_folds = 1;
end

% Store train and test accuracies
train_accs = zeros(n_folds, 1);
test_accs = zeros(n_folds, 1);

% Segment data into train and test using entire trials
segments_per_trial = floor((cfg.trialdef.poststim + cfg.trialdef.prestim - re_cfg.length) / (1-re_cfg.overlap)) + 1;
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
    % Shuffle and split dataset   
    right_indices = randperm(size(trial_right_indices, 1));
    left_indices = randperm(size(trial_left_indices, 1));
    
    test_start_indices = [trial_left_indices(left_indices(1:2), 1); trial_right_indices(right_indices(1:2), 1)];
    test_indices = [];
    for i=1:size(test_start_indices)
        idx = test_start_indices(i, 1):test_start_indices(i, 1)+segments_per_trial-1;
        test_indices = [test_indices, idx];
    end
    
    train_start_indices = [trial_left_indices(left_indices(3:end)); trial_right_indices(right_indices(3:end))];
    train_indices = [];
    for i=1:size(train_start_indices)
        idx = train_start_indices(i, 1):train_start_indices(i, 1)+segments_per_trial-1;
        train_indices = [train_indices, idx];
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

    % STEP 1 and 2: Apply filter and find CSP patterns
    n_feature_pairs = 4;
    fb_start_freq = 4;
    fb_end_freq = 40;
    filter_banks = fb_start_freq:4:fb_end_freq;
    % filter_banks = [4, 10, 30, 50, 80, 120, 200];
    % filter_banks = [1, 30, 40, 80, 100, 200];
    fb_output = zeros(size(filter_banks, 2)-1, size(train_X, 1), 4);
    csp_weights = zeros(size(filter_banks, 2)-1, nchan, nchan);
    for i=1:size(filter_banks, 2)-1
        fb_s_f = filter_banks(i);
        fb_e_f = filter_banks(i+1);
        filtered_data = zeros(size(train_X, 1), nchan, 1*hdr.Fs);
        fprintf('Filter Bank: [%d, %d]\n', fb_s_f, fb_e_f);
        fprintf('Setting up data and filtering it...\n');
        for j=1:size(train_X, 1)
            single_trail = reshape(train_X(j, :), [nchan, 1*hdr.Fs]);
            filtered_data(j, :, :) = ft_preproc_bandpassfilter(single_trail, hdr.Fs, [fb_s_f, fb_e_f], 3);
        end
        
        % filtered_data = common_average_referencing(filtered_data);

        % Find CSP filters
        class_dat = {};
        n_unique_classes = size(unique(train_Y), 1);
        for k=1:n_unique_classes
            class_dat{k} = filtered_data(train_Y==k-1, :, :);
        end
        fprintf('Finding CSP filters...\n\n');
        w = find_csp(class_dat);
        csp_weights(i, :, :) = w;
        fb_output(i, :, :) = apply_filter([class_dat{1}; class_dat{2}], w, 2);
    end

    % STEP 3: Perform feature selection
    fb_labels = [zeros(size(class_dat{1}, 1), 1); ones(size(class_dat{2}, 1), 1)];
    fb_output_r = zeros([size(fb_output, 2), size(fb_output, 1)*size(fb_output, 3)]);
    for i=1:size(fb_output, 2)
        t = zeros(1, size(fb_output, 1)*size(fb_output, 3));
        k = 1;
        for j=1:4:size(fb_output, 1)*size(fb_output, 3)
            t(1, j:j+3) = fb_output(k, i, :);
            k = k + 1;
        end
        fb_output_r(i, :) = t;
    end
    
    % Discretized on 10 bins of equal width and select features
    fs_features = discretize(fb_output_r, 10);
    idx = rank_mifsfs(fs_features, fb_labels);
    idx = flipud(idx);

    % Select most important and discriminable feature pair
    i = 1;
    j = 1;
    features_selected = zeros(n_feature_pairs * 2, 1);
    while i <= n_feature_pairs * 2
        feature_idx = idx(j);
        if mod(feature_idx, 4) <= 2 && mod(feature_idx, 4) ~= 0 && ~ismember(feature_idx, features_selected) && ~ismember(floor(feature_idx / 4) * 4 + 4, features_selected)  % First two indices in the block
            features_selected(i) = feature_idx;
            features_selected(i+1) = floor(feature_idx / 4) * 4 + 4;
            i = i + 2;
        elseif ~ismember(feature_idx, features_selected) && ~ismember(feature_idx - 3, features_selected) && mod(feature_idx, 4) == 0  % Exactly divisible
            features_selected(i) = feature_idx - 3;
            features_selected(i+1) = feature_idx;
            i = i + 2;
        elseif ~ismember(feature_idx, features_selected) && ~ismember(floor(feature_idx / 4) * 4 + 1, features_selected)  % 3 index in the block
            features_selected(i) = floor(feature_idx / 4) * 4 + 1;
            features_selected(i+1) = feature_idx;
            i = i + 2;
        end
        j = j + 1;
    end

    % Find frequency bins associated with the features selected
    j = 1;
    freq_bins_needed = zeros(n_feature_pairs, 2);
    for i=1:size(freq_bins_needed, 1)
        start_idx = ceil(features_selected(j)/4);
        freq_bins_needed(i, :) = [filter_banks(start_idx), filter_banks(start_idx+1)];
        j = j + 2;
    end
    
    fprintf('Fold: %d \t Freq bin selected: \n', fold);
    disp(freq_bins_needed);

    % Dataset used to train the classification model
    fb_train_x = fb_output_r(:, features_selected);
    fb_train_y = fb_labels;

    % Apply similar processing to test data
    j = 1;
    fb_test_x = zeros(size(test_X, 1), n_feature_pairs * 2);
    for i=1:size(freq_bins_needed, 1)
        fb_s_f = freq_bins_needed(i, 1);
        fb_e_f = freq_bins_needed(i, 2);
        filtered_data = zeros(size(test_X, 1), nchan, 1*hdr.Fs);
        
        fprintf('Filter Bank: [%d, %d]\n', fb_s_f, fb_e_f);
        fprintf('Setting up data and filtering it...\n');
        
        for k=1:size(test_X, 1)
            single_trail = reshape(test_X(k, :), [nchan, 1*hdr.Fs]);
            filtered_data(k, :, :) = ft_preproc_bandpassfilter(single_trail, hdr.Fs, [fb_s_f, fb_e_f], 3);
        end
        
        % filtered_data = common_average_referencing(filtered_data);

        % Find CSP filters
        class_dat = {};
        n_unique_classes = size(unique(test_Y), 1);
        for k=1:n_unique_classes
            class_dat{k} = filtered_data(test_Y==k-1, :, :);
        end

        % Use CSP weights found using train data
        weights_idx = ceil(features_selected(j)/4);
        w = squeeze(csp_weights(weights_idx, :, :));
        temp_data = apply_filter([class_dat{1}; class_dat{2}], w, 2);
        
        if mod(features_selected(j+1), 4) == 0
            features_to_use = [mod(features_selected(j), 4), 4];
        else
            features_to_use = [mod(features_selected(j), 4), mod(features_selected(j+1), 4)];
        end
        
        fb_test_x(:, [j, j+1]) = temp_data(:, features_to_use);
        fb_test_y = [zeros(size(class_dat{1}, 1), 1); ones(size(class_dat{2}, 1), 1)];
        j = j + 2;
    end
    
   % STEP 4: Feature classification
    rand_indices = randperm(size(fb_train_x, 1));
    fb_train_x = fb_train_x(rand_indices, :);
    fb_train_y = fb_train_y(rand_indices, :);

    % LDA
    classificationDiscriminant = fitcdiscr(...
    fb_train_x, ...
    fb_train_y, ...
    'DiscrimType', 'linear', ...
    'Gamma', 0.9, ...
    'FillCoeffs', 'off', ...
    'ClassNames', [0; 1]);

    % Create the result struct with predict function
    discriminantPredictFcn = @(x) predict(classificationDiscriminant, x);
    validationPredictFcn = @(x) discriminantPredictFcn(x);
    
    % Train Accuracy
    [trainPredictions, ~] = validationPredictFcn(fb_train_x);
    correctPredictions = (trainPredictions == fb_train_y);
    isMissing = isnan(fb_train_y);
    correctPredictions = correctPredictions(~isMissing);
    trainAccuracy = sum(correctPredictions)/length(correctPredictions) * 100;
    train_accs(fold, 1) = trainAccuracy;
    fprintf('Fold: %d \t Training Accuracy: %f\n', fold, trainAccuracy);
    
    % Test Accuracy
    [testPredictions, ~] = validationPredictFcn(fb_test_x);
    correctPredictions = (testPredictions == fb_test_y);
    isMissing = isnan(fb_test_y);
    correctPredictions = correctPredictions(~isMissing);
    validationAccuracy = sum(correctPredictions)/length(correctPredictions) * 100;
    test_accs(fold, 1) = validationAccuracy;
    fprintf('Fold: %d \t Testing Accuracy: %f\n', fold, validationAccuracy);
end

avg_train_acc = mean(train_accs);
std_train_acc = std(train_accs);
avg_test_acc = mean(test_accs);
std_test_acc = std(test_accs);

fprintf('\n%d Fold Train Accuracy: %f +- %f\n', fold, avg_train_acc, std_train_acc);
fprintf('%d Fold Test Accuracy: %f +- %f\n', fold, avg_test_acc, std_test_acc);

if (cfg.viz_csp_weights)
    visualize_csp_weights(w, hdr, cfg.subjectName);
end
