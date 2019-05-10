function one_hot_labels =  one_hot(labels)
% 2 Class only
    one_hot_labels = zeros(2, size(labels, 1));
    for i=1:size(labels, 1)
        if labels(i) == 0
            one_hot_labels(:, i) = [1; 0];
        else
            one_hot_labels(:, i) = [0; 1];
        end
    end
end