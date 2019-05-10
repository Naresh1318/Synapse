function Fp = apply_filter(data, W, m)
    % data -> [n_trails, n_channels, n_times]
    % w -> [n_channels, n_channels]
    % m -> reduce n_channels to this value
    
    required_W = zeros(2*m, size(W, 2));
    required_W(1:m, :) = W(1:m, :);
    required_W(m+1:2*m, :) = W(end-m+1:end, :);
    
    Z = zeros(size(data, 1), 2*m, size(data, 3));
    for i=1:size(data, 1)
       Z(i, :, :) = required_W * squeeze(data(i, :, :)); 
    end
    
    Fp = zeros(size(data, 1), 2*m);
    for trial=1:size(data, 1)
        den = sum(var(squeeze(Z(trial, :, :)), 0, 2));
        for i=1:2*m
           Fp(trial, i) = log(var(squeeze(Z(trial, i, :))) / den); 
        end
    end
end