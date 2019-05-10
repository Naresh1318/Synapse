clc;
clear;
load('./bci_3_4a_dataset/bci_no_expo_9.mat');

% Model parameters
sample_length = 1;
Fs = 250;
stride = 8;
n_folds = 1;

% Load training data
n_trials = size(train_data.X, 1);
n_channels = size(train_data.X, 2);
n_samples_per_trial = ceil((size(train_data.X, 3) - (sample_length * Fs)) / stride);

n_trials_needed = sum(train_data.y(1, :) == 0) + sum(train_data.y(1, :) == 1);
train_X = zeros(n_trials_needed*n_samples_per_trial, n_channels, Fs * sample_length);
train_Y = zeros(n_trials_needed*n_samples_per_trial, 1);

j = 1;
for t=1:n_trials
    if train_data.y(1, t) == 0 || train_data.y(1, t) == 1
        for i=sample_length*Fs:stride:size(train_data.X, 3)
            train_X(j, :, :) = train_data.X(t, :, (i-sample_length*Fs)+1:i);
            train_Y(j, 1) = train_data.y(1, t);
            j = j + 1;
        end
    end
end

% Load testing data
n_trials = size(test_set.X, 1);
n_channels = size(test_set.X, 2);
n_samples_per_trial = ceil((size(test_set.X, 3) - (sample_length * Fs)) / stride);

n_trials_needed = sum(test_set.y(1, :) == 0) + sum(test_set.y(1, :) == 1);
test_X = zeros(n_trials_needed*n_samples_per_trial, n_channels, Fs * sample_length);
test_Y = zeros(n_trials_needed*n_samples_per_trial, 1);

j = 1;
for t=1:n_trials
    if test_set.y(1, t) == 0 || test_set.y(1, t) == 1
        for i=sample_length*Fs:stride:size(test_set.X, 3)
            test_X(j, :, :) = test_set.X(t, :, (i-sample_length*Fs)+1:i);
            test_Y(j, 1) = test_set.y(1, t);
            j = j + 1;
        end
    end
end

% Store fold metrics and data
train_accs = zeros(n_folds, 1);
test_accs = zeros(n_folds, 1);
train_X = reshape(train_X, [size(train_X, 1), size(train_X, 2)*size(train_X, 3)]);
test_X = reshape(test_X, [size(test_X, 1), size(test_X, 2)*size(test_X, 3)]);
for fold=1:n_folds
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
    % filter_banks = [1, 4, 10, 30, 80, 200];
    % filter_banks = [1, 30, 40, 80, 100, 200];
    fb_output = zeros(size(filter_banks, 2)-1, size(train_X, 1), 4);
    csp_weights = zeros(size(filter_banks, 2)-1, n_channels, n_channels);
    for i=1:size(filter_banks, 2)-1
        fb_s_f = filter_banks(i);
        fb_e_f = filter_banks(i+1);
        filtered_data = zeros(size(train_X, 1), n_channels, 1*sample_length*Fs);
        fprintf('Filter Bank: [%d, %d]\n', fb_s_f, fb_e_f);
        fprintf('Setting up data and filtering it...\n');
        for j=1:size(train_X, 1)
            single_trail = reshape(train_X(j, :), [n_channels, 1*sample_length*Fs]);
            filtered_data(j, :, :) = ft_preproc_bandpassfilter(single_trail, Fs, [fb_s_f, fb_e_f]);
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
        filtered_data = zeros(size(test_X, 1), n_channels, sample_length*Fs);

        fprintf('Filter Bank: [%d, %d]\n', fb_s_f, fb_e_f);
        fprintf('Setting up data and filtering it...\n');

        for k=1:size(test_X, 1)
            single_trail = reshape(test_X(k, :), [n_channels, sample_length*Fs]);
            filtered_data(k, :, :) = ft_preproc_bandpassfilter(single_trail, Fs, [fb_s_f, fb_e_f]);
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

    % fb_test_x = normalize(fb_test_x, 2);

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
