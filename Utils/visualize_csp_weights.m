function visualize_csp_weights(w, hdr, subject_name)
    % load(strcat(datasetPath, '\csp_weights.mat'));
    % load(strcat(datasetPath, '\hdr.mat'));

    % Visualize commom spatial patterns
    w_inv = inv(w);
    required_w = w_inv(:, [1, 2, end-1, end]);
    figure;
    imagesc(required_w);
    title_str = sprintf('%s: Common Spatial Patters', subject_name);
    title(title_str);
    xlabel('CSP filters');
    ylabel('Channel names');
    colorbar;
    colormap jet;
    xticks(1:4);
    xticklabels({'CSP 0', 'CSP 1', 'CSP 62', 'CSP 63'});
    yticks(1:64);
    yticklabels(hdr.label);
end
