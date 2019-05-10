clc;
clear;
load('bci_no_expo_9.mat');

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

    % Find CSP filters
    class_dat = {};
    n_unique_classes = size(unique(train_Y), 1);
    for i=1:n_unique_classes
        class_dat{i} = train_X(train_Y==i-1, :);
        class_dat{i} = reshape(class_dat{i}, [size(class_dat{i}, 1), n_channels, sample_length * Fs]);
    end

    fprintf('Finding CSP filters...\n');
    w = find_csp(class_dat);
    csp_train_x = apply_filter([class_dat{1}; class_dat{2}], w, 2);
    csp_train_y = [zeros(size(class_dat{1}, 1), 1); ones(size(class_dat{2}, 1), 1)];

    % Preprocess test data using filter learnt from trian data
    csp_test_x = reshape(test_X, [size(test_X, 1), n_channels, sample_length * Fs]);
    csp_test_x = apply_filter(csp_test_x, w, 2);

    % Shuffe train data
    rand_indices = randperm(size(csp_train_x, 1));
    csp_train_x = csp_train_x(rand_indices, :);
    csp_train_y = csp_train_y(rand_indices, :);

    [SVMModel, FitInfo] = fitclinear(csp_train_x, csp_train_y, 'Verbose', 1);
    disp(FitInfo);

    % Training Accuracy
    estimate = predict(SVMModel, csp_train_x);
    pred = (estimate==csp_train_y);
    accuracy = mean(pred)*100;
    train_accs(fold, 1) = accuracy;
    fprintf('Fold: %d \t Training Accuracy: %f\n', fold, accuracy);

    % Testing Accuracy
    estimate = predict(SVMModel, csp_test_x);
    pred = (estimate==test_Y);
    accuracy = mean(pred)*100;
    test_accs(fold, 1) = accuracy;
    fprintf('Fold: %d \t Testing Accuracy: %f\n\n\n', fold, accuracy);
end

avg_train_acc = mean(train_accs);
std_train_acc = std(train_accs);
avg_test_acc = mean(test_accs);
std_test_acc = std(test_accs);

fprintf('\n%d Fold Train Accuracy: %f +- %f\n', fold, avg_train_acc, std_train_acc);
fprintf('%d Fold Test Accuracy: %f +- %f\n', fold, avg_test_acc, std_test_acc);
