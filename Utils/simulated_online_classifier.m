function simulated_online_classifier(cfg)
 
% online_classifier is an example realtime application for online
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
 
% Copyright (C) 2009, Robert Oostenveld
%
% Subversion does not use the Log keyword, use 'svn log <filename>' or 'svn -v log | less' to get detailled information
 
 
% set the default configuration options
if ~isfield(cfg, 'dataformat'),     cfg.dataformat = [];      end % default is detected automatically
if ~isfield(cfg, 'headerformat'),   cfg.headerformat = [];    end % default is detected automatically
if ~isfield(cfg, 'eventformat'),    cfg.eventformat = [];     end % default is detected automatically
if ~isfield(cfg, 'channel'),        cfg.channel = 'all';      end
if ~isfield(cfg, 'bufferdata'),     cfg.bufferdata = 'last';  end % first or last
 

% translate dataset into datafile+headerfile
cfg = ft_checkconfig(cfg, 'dataset2files', 'yes');
cfg = ft_checkconfig(cfg, 'required', {'datafile' 'headerfile'});
 
% ensure that the persistent variables related to caching are cleared
clear read_header
% start by reading the header from the realtime buffer
hdr = ft_read_header(cfg.headerfile, 'cache', true);
 
% define a subset of channels for reading
cfg.channel = ft_channelselection(cfg.channel, hdr.label);
chanindx    = match_str(hdr.label, cfg.channel);
nchan       = length(chanindx);
 
if nchan==0
	error('no channels were selected');
end

% Load the trained svm
load(cfg.modelPath);
load(strcat(cfg.datasetPath, '\csp_weights.mat'));

% Used to convert ints to volts
adBitVolts = 0.000000030517578125000001;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% this is the general BCI loop where realtime incoming data is handled
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


% determine latest header and event information
event = ft_read_event(cfg.dataset);  % only consider events that are later than the data processed sofar
hdr = ft_read_header(cfg.dataset, 'cache', true);  % the trialfun might want to use this, but it is not required

start_ts = 1551732752609407;
first_ts = event(1).timestamp;

begin_time_stamp_1 = fix((start_ts - first_ts) / 500) + 1;
begin_time_stamp_2 = event(17).sample;
begin_time_stamp = begin_time_stamp_1 + fix((begin_time_stamp_2 - begin_time_stamp_1)/2) + 50;
end_time_stamp = begin_time_stamp + 1999;
while true
        hdr = ft_read_header(cfg.dataset, 'cache', true);  % the trialfun might want to use this, but it is not required
        fprintf('\n******************************\n');
        fprintf('nSamples: %d \n', hdr.nSamples);
        fprintf('Begin: %d \n', begin_time_stamp);
        fprintf('End: %d \n', end_time_stamp);
        current_data = ft_read_data(cfg.datafile, 'header', hdr, 'begsample', begin_time_stamp, 'endsample', end_time_stamp, 'chanindx', chanindx, 'checkboundary', false);
        % current_data = current_data .* adBitVolts .* 1e6;  % Convert to uV

        current_data = ft_preproc_baselinecorrect(current_data);
        [current_data] = ft_preproc_bandpassfilter(current_data, hdr.Fs, cfg.freq, 3);  % 3rd order two-pass butterworth filter

        % Make an Inference
        [n_channels, n_samples] = size(current_data);
        current_data = reshape(current_data, [1, n_channels, n_samples]);
        current_data = apply_filter(current_data, w, 2);
        estimation = predict(SVMModel, current_data);

        fprintf('Estimation: %d \n', estimation);

        end_time_stamp = end_time_stamp + fix(hdr.Fs*(1-cfg.overlap));
        begin_time_stamp = begin_time_stamp + fix(hdr.Fs*(1-cfg.overlap));
end
