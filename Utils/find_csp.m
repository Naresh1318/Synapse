function [W] = find_csp(data)
% data -> {[n_trails, n_channels, n_time_steps]}

    assert(size(data{1}, 2)==size(data{2}, 2), 'number of channels in class 1 and 2 must be equal');
    spatial_cov = {0, 0};
    for i=1:2
        sum_s_cov = zeros(size(data{i}, 2), size(data{i}, 2));
        for j=1:size(data{i}, 1)
           s_cov = (squeeze(data{i}(j, :, :))*squeeze(data{i}(j, :, :))')./trace(squeeze(data{i}(j, :, :))*squeeze(data{i}(j, :, :))');
           sum_s_cov = sum_s_cov + s_cov;
        end
        spatial_cov{i} = sum_s_cov ./ size(data{i}, 1);
    end
    
    Cc = spatial_cov{1} + spatial_cov{2};
    
    % Find the eigenvector and eigenvalue of Cc
    [U, V] = eig(Cc);
    % Sort eigenvalues and eigenvectors in descending order
    [V, ind] = sort(diag(V), 'descend');
    U = U(:, ind);
    
    % Whitening transform
    P = sqrt(inv(diag(V))) * U';
    
    S = {0, 0};
    for i=1:2
        S{i} = P * spatial_cov{i} * P';
    end
    
    [B, V] = eig(S{1});

    % Sort in ascending order
    [~, ind] = sort(diag(V));
    B = B(:, ind);

    % Find the decomposition matrix
    W = B' * P;
end