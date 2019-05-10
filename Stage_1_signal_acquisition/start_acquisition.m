sca;
close all;
clearvars;
matlab_config;

cd(projectPath);

% Add this project to the path
addpath(genpath('./'));

% Save logs
diary(strcat(datasetPath, '\log_stage_1.txt'));

% Sets the default psychtoolbox parameters
PsychDefaultSetup(2);
Screen('Preference', 'SkipSyncTests', 1);  % SkipSyncTests -> 0, do not skip
                                           %               -> 1, skip

% BCI presentation parameters
n_baselines = 2;      % Initial trials which are generally ignored
n_trials = 12;        % No. of trials for each class
time_inst = 30;       % time in s to show instructions
time_rest_init = 10;  % time in s that the participant rests
time_rest_start = 2;  % time in s between the setup and class pulse
time_trial = 4;       % time in s for each trial, execuliding rest
time_trial_rest = 2;  % time in s for rest trail
time_rest_after = 3;  % time in s after each trial, the user is expected to rest
classes = {'rest', 'left', 'right'};  % class names

% Setup TTL values
ttl_values = {};
ttl_values.start = 0;                 % Start pulse
ttl_values.setup = 8;                 % Setup pulse
ttl_values.classes = {64, 128, 192};  % Class pulses

% Setup Event_ids, this is not really used by us
event_ids = {};                    
event_ids.start = 0;            % Start pulse id
event_ids.setup = 1;            % Setup pulse id
event_ids.classes = {2, 3, 4};  % The event ids for each class

% Connect to the Data Acquisition Server (DAS)
fprintf('Connecting to %s...\n', serverName);
succeeded = NlxConnectToServer(serverName);
if succeeded ~= 1
    fprintf('FAILED to connect. Exiting script.\n');
    return;
else
    fprintf('Connect successful.\n');
end

serverIP = NlxGetServerIPAddress();
fprintf('Connected to IP address: %s\n', serverIP);

serverPCName = NlxGetServerPCName();
fprintf('Connected to PC named: %s\n', serverPCName);

serverApplicationName = NlxGetServerApplicationName();
fprintf('Connected to the NetCom server application: %s\n', serverApplicationName);

% Identify this program to the server we're connected to.
succeeded = NlxSetApplicationName('Signal_acquisition_script');
if succeeded ~= 1
    fprintf('FAILED to set the application name\n');
end

% Setup Pyschtoolbox
screens = Screen('Screens');
screenNumber = max(screens);  % Change this to the desired monitor number, the default monitor has a value of 0
white = WhiteIndex(screenNumber);  % Reference white needed later
black = BlackIndex(screenNumber);  % Reference black needed later
[window, windowRect] = PsychImaging('OpenWindow', screenNumber, black);

% Set up alpha-blending for smooth (anti-aliased) lines
Screen('BlendFunction', window, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');

% Get the size of the on screen window
[screenXpixels, screenYpixels] = Screen('WindowSize', window);

% Setup the text type for the window
Screen('TextFont', window, 'Ariel');
Screen('TextSize', window, 50);

% Get the centre coordinate of the window-
[xCenter, yCenter] = RectCenter(windowRect);

% Instruction screen parameters
instBaseRect = [0 0 450 350];

% Screen X and Y positions of our rectangles and text
RowXpos = [screenXpixels * 0.13 screenXpixels * 0.55];
ColYpos = [screenYpixels * 0.20 screenYpixels * 0.80];
RowXtext = [screenXpixels * 0.25 screenXpixels * 0.67];
ColYtext = [screenYpixels * 0.20 screenYpixels * 0.80];
numSqaures = length(RowXpos)*length(ColYpos);

% Set the colors to Red, Green and Blue
instAllColors = [1 0 0];

% Here we set the size of the arms of our fixation cross
instFixCrossDimPix = 70;

% Set the line width for our fixation cross
instLineWidthPix = 2;

% Now we set the coordinates (these are all relative to zero we will let
% the drawing routine center the cross in the center of our monitor for us)
instxCoords = [-instFixCrossDimPix instFixCrossDimPix 0 0];
instyCoords = [0 0 -instFixCrossDimPix instFixCrossDimPix];
installCoords = [instxCoords; instyCoords];

textString1 = [sprintf('Prepare')];
textString2 = [sprintf('Onset')];
textString3 = [sprintf('Motion: Left/Right')];
textString4 = [sprintf('Rest')];

% Create a triangle
instBaseArrowRect = [0 0 30 15]; 
inst_right_centeredRect = CenterRectOnPointd(instBaseArrowRect, RowXpos(2)+instBaseArrowRect(3)/2, ColYpos(1));

inst_right_head = [RowXpos(2)+instBaseArrowRect(3), ColYpos(1)];   % coordinates of head

inst_width  = 15;                                      % width of arrow head
inst_right_points = [inst_right_head-[0, inst_width]   % left corner
                     inst_right_head+[0, inst_width]   % right corner
                     inst_right_head+[inst_width, 0]]; % vertex
       
% Rest circle
inst_rest_baseCir = [0 0 30 30];

% For Ovals we set a miximum diameter up to which it is perfect for
instMaxDiameter = max(inst_rest_baseCir) * 1.00;

% Center the rectangle on the centre of the screen
inst_rest_centeredRect = CenterRectOnPointd(inst_rest_baseCir, RowXpos(2), ColYpos(2));
       
% Make our rectangle coordinates
allRects = nan(4, 3);
for i = 1:numSqaures
    if mod(i, 2) == 0 
        allRects(:, i) = CenterRectOnPointd(instBaseRect, RowXpos(i/2), ColYpos(2));
    else
        allRects(:, i) = CenterRectOnPointd(instBaseRect, RowXpos((i+1)/2), ColYpos(1));
    end
end 

% Here we set the size of the arms of our fixation cross
fixCrossDimPix = 400;

% Set the line width for our fixation cross
lineWidthPix = 4;

% Now we set the coordinates (these are all relative to zero we will let
% the drawing routine center the cross in the center of our monitor for us)
xCoords = [-fixCrossDimPix fixCrossDimPix 0 0];
yCoords = [0 0 -fixCrossDimPix fixCrossDimPix];
allCoords = [xCoords; yCoords];

% Arrow
baseRect = [0 0 400 150]; 
right_centeredRect = CenterRectOnPointd(baseRect, xCenter+200, yCenter);
left_centeredRect = CenterRectOnPointd(baseRect, xCenter-200, yCenter);
rectColor = [1 0 0];

% Create a triangle
right_head = [ xCenter+400, yCenter ];   % coordinates of head
left_head = [ xCenter-400, yCenter ];
width  = 150;                            % width of arrow head
right_points = [ right_head-[0, width]   % left corner
           right_head+[0, width]         % right corner
           right_head+[width, 0] ];      % vertex
       
left_points = [ left_head-[0, width]     % left corner
           left_head+[0, width]          % right corner
           left_head-[width, 0] ];       % vertex
       
% Rest circle
rest_baseCir = [0 0 200 200];

% For Ovals we set a miximum diameter up to which it is perfect for
maxDiameter = max(rest_baseCir) * 1.00;

% Center the rectangle on the centre of the screen
rest_centeredRect = CenterRectOnPointd(rest_baseCir, xCenter, yCenter);

% ifi is used to get the interval between each of the consequitive frames
ifi = Screen('GetFlipInterval', window);
waitFrames = 1;
            
% Priority management to get consistant framerates
topPriorityLevel = MaxPriority(window);
Priority(topPriorityLevel);

vbi = Screen('Flip', window);

% Start Neuralynx Acquisition
[succeeded, reply] = NlxSendCommand('-GetDASState');
if succeeded == 0
    fprintf('Failed to get DAS state\n');
else
    if strcmp(reply, 'Idle') == 1
        [succeeded, ~] = NlxSendCommand('-StartAcquisition');
        % Start Neuralynx Recording
        [~, ~] = NlxSendCommand('-StartRecording');
        [~, ~] = NlxSendCommand('-SetRawDataFile AcqSystem1 "RawData.nrd"');
        if succeeded == 0
            fprintf('Failed to start acquisition\n');
        end
    end
end

% Start Presenation and transmit the start pulse
command = sprintf('-PostEvent "start_pulse" %d %d', ttl_values.start, event_ids.start);
[~, ~] = NlxSendCommand(command);

% Wait for keyboard response
rightKey = KbName('RightArrow');
respToBeMade = true;
while respToBeMade == true
    Screen('FrameRect', window, instAllColors, allRects);
    Screen('DrawLines', window, installCoords, instLineWidthPix, white, [RowXpos(1) ColYpos(2)], 2);
    Screen('DrawLines', window, installCoords, instLineWidthPix, white, [RowXpos(2) ColYpos(1)], 2);
    Screen('FillRect', window, [1,0,0], inst_right_centeredRect);
    Screen('FillPoly', window, [1,0,0], inst_right_points);
    Screen('FillOval', window, [1,0,0], inst_rest_centeredRect, instMaxDiameter);
    Screen('DrawText', window, textString1, RowXtext(1), ColYtext(1), 1, 0, 0);
    Screen('DrawText', window, textString2, RowXtext(1), ColYtext(2), 1, 0, 0);
    Screen('DrawText', window, textString3, RowXtext(2), ColYtext(1), 1, 0, 0);
    Screen('DrawText', window, textString4, RowXtext(2), ColYtext(2), 1, 0, 0);
    
    % Check the keyboard. The person should press the
    [~, ~, keyCode] = KbCheck;
    if keyCode(rightKey)
        respToBeMade = false;
    end

    % Flip to the screen
    vbi = Screen('Flip', window, vbi + (waitFrames - 0.5) * ifi);
end

% Finding the number of frames during the rest period
numFrames = round(time_rest_init / ifi);

% Start Presenation and transmit the start pulse
command = sprintf('-PostEvent "start_pulse" %d %d', ttl_values.start, event_ids.start);
[~, ~] = NlxSendCommand(command);

for frame=1:numFrames
	textString = [sprintf('Wait for %ds', time_rest_init)];
    % Text output of mouse position draw in the centre of the screen
	Screen('DrawText', window, textString, 500, 500, 1, 0, 0);
	vbi = Screen('Flip', window, vbi+(waitFrames - 0.5) * ifi); 
end

% Count for the number of classes remianing
classes_remaining = {};
classes_remaining.left = n_trials + floor(n_baselines/(numel(classes)-1));
classes_remaining.right = n_trials + floor(n_baselines/(numel(classes)-1));

if floor(n_baselines/(numel(classes)-1)) * (numel(classes)-1) ~= n_baselines
    error('Baseline values for each class does not add up\n');
end

step = 1;
for trail_n=1:n_trials*2+n_baselines
    fprintf("Trial number:" + string(step) + "\n");
    step = step + 1;
    
    % Setup
    numFrames = round(time_rest_start / ifi);
    command = sprintf('-PostEvent "setup_pulse" %d %d', ttl_values.setup, event_ids.setup);
    [~, ~] = NlxSendCommand(command);
    
    for frame=1:numFrames
        % Draw the fixation cross in white, set it to the center of our screen and
        % set good quality antialiasing
        Screen('DrawLines', window, allCoords, lineWidthPix, white, [xCenter yCenter], 2);
        vbi = Screen('Flip', window, vbi+(waitFrames - 0.5) * ifi); 
    end
    
    % Number of frames during each trial
    numFrames = round(time_trial / ifi);
    
    % Choose a class randomly and update the class_remaining struct
    class_chosen = double(rand(1) > 0.5);
    if class_chosen == 0
        if classes_remaining.left <= 0
            class_chosen = 'right';
            ttl_class = 3;
            classes_remaining.right = classes_remaining.right - 1;
            centeredRect = right_centeredRect;
            points = right_points;
        else
            class_chosen = 'left';
            ttl_class = 2;
            classes_remaining.left = classes_remaining.left - 1;
            centeredRect = left_centeredRect;
            points = left_points;
        end
    else
        if classes_remaining.right <= 0
            class_chosen = 'left';
            ttl_class = 2;
            classes_remaining.left = classes_remaining.left - 1;
            centeredRect = left_centeredRect;
            points = left_points;
        else
            class_chosen = 'right';
            ttl_class = 3;
            classes_remaining.right = classes_remaining.right - 1;
            centeredRect = right_centeredRect;
            points = right_points;
        end
    end
       
    % Play audio
    if strcmp(class_chosen, 'left')
        [wavedata, freq] = audioread('./Sounds/Audio_left.wav');
        beep1 = audioplayer(wavedata',freq);
        play(beep1);
    else
        [wavedata, freq] = audioread('./Sounds/Audio_right.wav');
        beep2 = audioplayer(wavedata',freq);
        play(beep2);
    end
    
    command = sprintf('-PostEvent "%s" %d %d', class_chosen, ttl_values.classes{ttl_class}, event_ids.classes{ttl_class});
    [~, ~] = NlxSendCommand(command);
    for frame=1:numFrames
        Screen('DrawLines', window, allCoords, lineWidthPix, white, [xCenter yCenter], 2);
        Screen('FillRect', window, rectColor, centeredRect);
        Screen('FillPoly', window, [1,0,0], points);
        vbi = Screen('Flip', window, vbi+(waitFrames - 0.5) * ifi); 
    end
    
    % End
    command = sprintf('-PostEvent "end" %d %d', 0, event_ids.start);
    [~, ~] = NlxSendCommand(command);
    numFrames = round(time_rest_after / ifi);
    for frame=1:numFrames
    	% Construct our text string
        textString = [sprintf('Short Rest')];
        % Text output of mouse position draw in the centre of the screen
        Screen('DrawText', window, textString, 500, 500, 1, 0, 0);
        vbi = Screen('Flip', window, vbi+(waitFrames - 0.5) * ifi); 
    end
    
    
    % Rest class
    numFrames = round(time_rest_start / ifi);
    command = sprintf('-PostEvent "setup_pulse" %d %d', ttl_values.setup, event_ids.setup);
    [~, ~] = NlxSendCommand(command);
    for frame=1:numFrames
        Screen('DrawLines', window, allCoords, lineWidthPix, white, [xCenter yCenter], 2);
        vbi = Screen('Flip', window, vbi+(waitFrames - 0.5) * ifi); 
    end
    
    class_chosen = 'rest';
    command = sprintf('-PostEvent "%s" %d %d', class_chosen, ttl_values.classes{1}, event_ids.classes{1});
    [~, ~] = NlxSendCommand(command);
    numFrames = round(time_trial_rest / ifi);
    for frame=1:numFrames
        % Draw the rect to the screen
        Screen('FillOval', window, rectColor, rest_centeredRect, maxDiameter);
        vbi = Screen('Flip', window, vbi+(waitFrames - 0.5) * ifi); 
    end
    
    % End
    command = sprintf('-PostEvent "end" %d %d', 0, event_ids.start);
    [~, ~] = NlxSendCommand(command);
    numFrames = round(time_rest_after / ifi);
    for frame=1:numFrames
    	% Construct our text string
        textString = [sprintf('Short Rest')];
        % Text output of mouse position draw in the centre of the screen
        Screen('DrawText', window, textString, 500, 500, 1, 0, 0);
        vbi = Screen('Flip', window, vbi+(waitFrames - 0.5) * ifi); 
    end
end

numFrames = round(time_rest_after / ifi);
for frame=1:numFrames
    % Construct our text string
    textString = [sprintf('Thank You!')];
    % Text output of mouse position draw in the centre of the screen
    Screen('DrawText', window, textString, 500, 500, 1, 0, 0);
    vbi = Screen('Flip', window, vbi+(waitFrames - 0.5) * ifi); 
end

% Stop Recording
[succeeded, ~] = NlxSendCommand('-StopRecording');
if succeeded == 0
    fprintf('Failed to stop recording\n');
end

% Stop Acquisition
[succeeded, ~] = NlxSendCommand('-StopAcquisition');
if succeeded == 0
    fprintf('Failed to stop acquisition\n');
end

% Disconnects from the server and shuts down NetCom
succeeded = NlxDisconnectFromServer();
if succeeded ~= 1
    fprintf('FAILED disconnect from server\n');
else
    fprintf('Disconnected from %s\n', serverName);
end

% remove all vars created in this script
clear;
sca;

% Start Stage 2
fprintf("\n Stage 2 Started!\n");
!matlab -r start_training &
exit
