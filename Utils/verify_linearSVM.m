trial_sum = 0;

for i=1:size(data_x, 1)
    current_data = squeeze(data_x(i, :, :));

    [current_data] = ft_preproc_bandpassfilter(current_data, 2000, [8 400]);

    [n_channels, n_samples] = size(current_data);

    % fprintf('shape: %d, %d \n', n_channels, n_samples);

    data = reshape(current_data, 1, n_channels*n_samples);

    % Get the estimate for the data
    estimation = predict(SVMModel, data);

    fprintf('Step: %d \t Estimation: %d \n', i, estimation);
    
    if estimation == 1
        trial_sum = trial_sum + 1;
    else
        trial_sum = trial_sum - 1;
    end
 
    if trial_sum >= 28 || trial_sum <= -28
        break
    end
    
    
end

fprintf('Sum: %d \t Steps: %d', trial_sum, i);
