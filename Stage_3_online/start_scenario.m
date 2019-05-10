% Clear the workspace and the screen
sca;
close all;
clearvars;
matlab_config;

prompt = 'Have you started Pegasus again to record from this scenario? Y/N [Y]: ';
str = input(prompt,'s');
if isempty(str)
    str = 'Y';
end

if strcmp(str, 'Y') || strcmp(str, 'y') || strcmp(str, 'Yes') || strcmp(str, 'yes')

% Add this project to the path
cd(projectPath);
addpath(genpath('./'));

% Save logs
diary(strcat(datasetPath, '\log_stage_3_scenario.txt'));

% BCI presentation parameters
n_baselines = 2;        % must be a multiple of the number of class members
n_trials = 10;          % for each class
n_blocks = 2;           % number of times to repeat the experiment
time_instructions = 30; % time in s, to show the instructions on the screen TODO: 30
time_rest_init = 5;     % do nothing for _s in the beginning TODO: 10
time_setup_start = 2;   % time in s between the setup and show ball pulse
time_ball_start = 2;    % time in s between the ball pulse and paddle pulse
time_paddle_start = 2;  % time in s between the paddle pulse and class pulse
time_trial = 4*2;       % time taken in s for each trial is doubled during stage 3
frames_per_sec = 32;    % FPS for the scenario

classes = {'rest', 'left', 'right'};  % class names

% Setup TTL values
ttl_values = {};
ttl_values.instruction = 0;           % Instruction pulse
ttl_values.start = 1;                 % Start pulse
ttl_values.setup = 8;                 % Setup pulse
ttl_values.ball = 16;                 % ball pulse
ttl_values.paddle = 24;               % paddle pulse
ttl_values.classes = {64, 128, 192};  % Class pulses

% Setup Event_ids, this is not really used by us
event_ids = {};   
event_ids.instruction = 0;            % Instruction pulse id
event_ids.start = 1;                  % Start pulse id
event_ids.setup = 2;                  % Setup pulse id
event_ids.ball = 3;                   % ball pulse
event_ids.paddle = 4;                 % paddle pulse
event_ids.classes = {5, 6, 7};        % The event ids for each class

% Connect to the Data Acquisition Server (DAS)
fprintf('Connecting to %s...', serverName);
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
succeeded = NlxSetApplicationName('Signal_Online_script');
if succeeded ~= 1
    fprintf('FAILED to set the application name\n');
end

% Setup LSL library
fprintf('Loading the library...\n');
lib = lsl_loadlib();

% resolve a stream...
fprintf('Resolving an EEG stream...\n');
result = {};
while isempty(result)
    result = lsl_resolve_byprop(lib,'name','ECoG_online'); 
end

% create a new inlet
fprintf('Opening an inlet...\n');
inlet = lsl_inlet(result{1});

% Here we call some default settings for setting up Psychtoolbox
PsychDefaultSetup(2);
Screen('Preference', 'SkipSyncTests', 1);

% Get the screen numbers
screens = max(Screen('Screens'));

% Draw to the external screen if avaliable
screenNumber = max(screens);

% Define black and white
white = WhiteIndex(screenNumber);
black = BlackIndex(screenNumber);

% Open an on screen window
[window, windowRect] = PsychImaging('OpenWindow', screenNumber, black);

% Get the size of the on screen window
[screenXpixels, screenYpixels] = Screen('WindowSize', window);

% Set up alpha-blending for smooth (anti-aliased) lines
Screen('BlendFunction', window, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');

% Get the centre coordinate of the window
[xCenter, yCenter] = RectCenter(windowRect);

% Make a base Rect of 200 by 200 pixels
baseCir = [0 0 200 200];

% Make a rectangle of 400 by 100 pixels
baseLeftRect = [0 0 100 400];
baseRightRect = [0 0 100 400];

% Left rect center
xLeftRect = round(baseLeftRect(3)/2);
xRightRect = round(screenXpixels - (baseRightRect(3)/2));

centeredLeftRect = CenterRectOnPointd(baseLeftRect, xLeftRect, yCenter);
centeredRightRect = CenterRectOnPointd(baseRightRect, xRightRect, yCenter);

% Set the color of the rect to red
cirColor = [1 0 0];
rectColor = [1 1 1];
cirWhiteColor = [1 1 1];

% Setup the text type for the window
Screen('TextFont', window, 'Ariel');
Screen('TextSize', window, 50);

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


% create a triangle
right_head = [ xCenter+400, yCenter ];   % coordinates of head
left_head = [ xCenter-400, yCenter ];
width  = 150;                            % width of arrow head
right_points = [ right_head-[0, width]   % left corner
           right_head+[0, width]         % right corner
           right_head+[width, 0] ];      % vertex
       
left_points = [ left_head-[0, width]     % left corner
           left_head+[0, width]          % right corner
           left_head-[width, 0] ];       % vertex


% Sync us and get a time stamp
vbl = Screen('Flip', window);

% For Ovals we set a miximum diameter up to which it is perfect for
maxDiameter = max(baseCir) * 1.00;

% ifi is used to get the interval between each of the consequitive frames
ifi = Screen('GetFlipInterval', window);
waitFrames = 1;

% Maximum priority level
topPriorityLevel = MaxPriority(window);
Priority(topPriorityLevel);

vbi = Screen('Flip', window);

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

% Make a base Rect of 200 by 200 pixels
instBaseCir = [0 0 200 200];

% Now we set the coordinates (these are all relative to zero we will let
% the drawing routine center the cross in the center of our monitor for us)
instxCoords = [-instFixCrossDimPix instFixCrossDimPix 0 0];
instyCoords = [0 0 -instFixCrossDimPix instFixCrossDimPix];
installCoords = [instxCoords; instyCoords];

textString1 = [sprintf('Blank')];
textString2 = [sprintf('Prepare')];
textString3 = [sprintf('Onset')];
textString4 = [sprintf('Motion: Left/Right')];

% Make a rectangle of 400 by 100 pixels
baseLeftRect = [0 0 30 65];
baseRightRect = [0 0 30 65];

% Left rect center
xLeftRect1 = round(baseLeftRect(3)/2)+RowXpos(2)-instBaseRect(3)/2;
xLeftRect2 = round(baseLeftRect(3)/2)+RowXpos(2)-instBaseRect(3)/2;

xRightRect1 = round(RowXpos(2) + instBaseRect(3)/2 - (baseRightRect(3)/2));
xRightRect2 = round(RowXpos(2) + instBaseRect(3)/2 - (baseRightRect(3)/2));

centeredLeftRect1 = CenterRectOnPointd(baseLeftRect, xLeftRect1, ColYpos(1));
centeredRightRect1 = CenterRectOnPointd(baseRightRect, xRightRect1, ColYpos(1));

centeredLeftRect2 = CenterRectOnPointd(baseLeftRect, xLeftRect2, ColYpos(2));
centeredRightRect2 = CenterRectOnPointd(baseRightRect, xRightRect2, ColYpos(2));
       
% Rest circle
inst_rest_baseCir = [0 0 30 30];

% For Ovals we set a miximum diameter up to which it is perfect for
instMaxDiameter = max(inst_rest_baseCir) * 1.00;
  
inst_Cir1 = CenterRectOnPointd(inst_rest_baseCir, RowXpos(1), ColYpos(2));
inst_Cir2 = CenterRectOnPointd(inst_rest_baseCir, RowXpos(2), ColYpos(1));
inst_Cir3 = CenterRectOnPointd(inst_rest_baseCir, RowXpos(2), ColYpos(2));

% Make our rectangle coordinates
allRects = nan(4, 3);
for i = 1:numSqaures
    if mod(i, 2) == 0 
        allRects(:, i) = CenterRectOnPointd(instBaseRect, RowXpos(i/2), ColYpos(2));
    else
        allRects(:, i) = CenterRectOnPointd(instBaseRect, RowXpos((i+1)/2), ColYpos(1));
    end
end 

% Start Neuralynx Acquisition
[succeeded, reply] = NlxSendCommand('-GetDASState');
if succeeded == 0
    fprintf('Failed to get DAS state\n');
else
    % Start Neuralynx Recording
    [~, ~] = NlxSendCommand('-StartRecording');
    [~, ~] = NlxSendCommand('-SetRawDataFile AcqSystem1 "RawData.nrd"');
    if succeeded == 0
        fprintf('Failed to start acquisition\n');
    end
end

% Start Presenation and transmit the start pulse
command = sprintf('-PostEvent "start_instruction_pulse" %d %d', ttl_values.start, event_ids.start);
[~, ~] = NlxSendCommand(command);

% Wait for keyboard response
rightKey = KbName('RightArrow');
respToBeMade = true;
while respToBeMade == true
    
    % Draw on the screen
    Screen('FrameRect', window, instAllColors, allRects);
    Screen('FillOval', window, [1 1 1], inst_Cir1, instMaxDiameter);
    Screen('FillOval', window, [1 0 0], inst_Cir2, instMaxDiameter);
    Screen('FillOval', window, [1 0 0], inst_Cir3, instMaxDiameter);
    
    Screen('FillRect', window, rectColor, centeredLeftRect1);
    Screen('FillRect', window, rectColor, centeredRightRect1);
    Screen('FillRect', window, rectColor, centeredLeftRect2);
    Screen('FillRect', window, [1 0 0], centeredRightRect2);
    
    Screen('DrawText', window, textString1, RowXtext(1), ColYtext(1), 1, 0, 0);
    Screen('DrawText', window, textString2, RowXtext(1), ColYtext(2), 1, 0, 0);
    Screen('DrawText', window, textString3, RowXtext(2), ColYtext(1), 1, 0, 0);
    Screen('DrawText', window, textString4, RowXtext(2), ColYtext(2), 1, 0, 0);
    
    % Check the keyboard. The person should press the
    [keyIsDown,secs, keyCode] = KbCheck;
    if keyCode(rightKey)
        response = 3;
        respToBeMade = false;
    end

    % Flip to the screen
	vbi = Screen('Flip', window, vbi+(waitFrames - 0.5) * ifi); 
end

% Finding the number of frames during the rest period
numFrames = round(time_rest_init / ifi);

% Start Presenation and transmit the start pulse
command = sprintf('-PostEvent "start_pulse" %d %d', ttl_values.start, event_ids.start);
[~, ~] = NlxSendCommand(command);

for frame=1:numFrames
	textString = [sprintf('Setting Up Experiment!')];
    % Text output of mouse position draw in the centre of the screen
	Screen('DrawText', window, textString, 500, 500, 1, 0, 0);
	vbi = Screen('Flip', window, vbi+(waitFrames - 0.5) * ifi); 
end

% Experiment Stats
Trial = [];
Target = [];
Hit = [];
TimeSteps = [];

continue_with_experiment = true;
step = 1;

for block=1:n_blocks
    if ~continue_with_experiment
        break;
    end
    
    % Count for the number of classes remianing
    classes_remaining = {};
    classes_remaining.left = n_trials + floor(n_baselines/(numel(classes)-1));
    classes_remaining.right = n_trials + floor(n_baselines/(numel(classes)-1));

    if floor(n_baselines/(numel(classes)-1)) * (numel(classes)-1) ~= n_baselines
        error('Not of baseline values for each class does not add up');
    end

    for trail_n=1:n_trials*2+n_baselines
        fprintf("Trial number:" + string(step) + "\n");
        step = step + 1;
        
        if isempty(Trial)
            Trial = [Trial; 1];
        else
            Trial = [Trial; Trial(end)+1];
        end

        % Setup
        command = sprintf('-PostEvent "setup_pulse" %d %d', ttl_values.setup, event_ids.setup);
        [~, ~] = NlxSendCommand(command);
        numFrames = round(time_setup_start / ifi);
        for frame=1:numFrames
            vbi = Screen('Flip', window, vbi+(waitFrames - 0.5) * ifi); 
        end

        % Show ball
        numFrames = round(time_ball_start / ifi);
        command = sprintf('-PostEvent "ball_pulse" %d %d', ttl_values.ball, event_ids.ball);
        [~, ~] = NlxSendCommand(command);

        for frame=1:numFrames
            % Center the rectangle on the centre of the screen
            centeredCir = CenterRectOnPointd(baseCir, xCenter, yCenter);
            % Draw the rect to the screen
            Screen('FillOval', window, cirWhiteColor, centeredCir, maxDiameter);
            vbi = Screen('Flip', window, vbi+(waitFrames - 0.5) * ifi); 
        end

        % Show paddle
        numFrames = round(time_paddle_start / ifi);
        command = sprintf('-PostEvent "setup_pulse" %d %d', ttl_values.paddle, event_ids.paddle);
        [~, ~] = NlxSendCommand(command);

        for frame=1:numFrames
            % Center the rectangle on the centre of the screen
            centeredCir = CenterRectOnPointd(baseCir, xCenter, yCenter);
            % Draw the rect to the screen
            Screen('FillOval', window, cirColor, centeredCir, maxDiameter);
            Screen('FillRect', window, rectColor, centeredLeftRect);
            Screen('FillRect', window, rectColor, centeredRightRect);
            vbi = Screen('Flip', window, vbi+(waitFrames - 0.5) * ifi); 
        end

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

        fprintf("Class Chosen: " + string(class_chosen) + "\n");

        % Play audio
        if strcmp(class_chosen, 'left')
            [wavedata, freq] = audioread('./Sounds/Audio_left.wav');
            beep1 = audioplayer(wavedata',freq);  % Do not move this out of the loop
            play(beep1);
        else
            [wavedata, freq] = audioread('./Sounds/Audio_right.wav');
            beep2 = audioplayer(wavedata',freq);
            play(beep2);
        end

        % All targets are white by default
        leftRectColor = [1 1 1];
        rightRectColor = [1 1 1];

        if strcmp(class_chosen, 'right')
            rightRectColor = [1 0 0];
        else
            leftRectColor = [1 0 0];
        end

        % Center the cursor before each trail
        xCirCenter = xCenter;

        % Used to check if the target has been hit
        targetHit = false;

        % Number of frames during each trial
        numFrames = round(time_trial * frames_per_sec);

        % Reset the time interval in LSL
        fprintf('Opening an inlet...\n');
        inlet = lsl_inlet(result{1});

        command = sprintf('-PostEvent "%s" %d %d', class_chosen, ttl_values.classes{ttl_class}, event_ids.classes{ttl_class});
        [~, ~] = NlxSendCommand(command);
        
        Target = [Target; string(class_chosen)];

        for frame=1:numFrames  
            [vec, ts] = inlet.pull_sample();
            fprintf('%.2f\t',vec);
            fprintf('%.5f\n',ts);

            % Move the cursor towards the left or right
            if vec == 0
                xCirCenter = xCirCenter - 30;
            else
                xCirCenter = xCirCenter + 30;
            end

            % Center the rectangle on the centre of the screen
            centeredCir = CenterRectOnPointd(baseCir, xCirCenter, yCenter);

            % Draw the rect to the screen
            Screen('FillOval', window, cirColor, centeredCir, maxDiameter);
            Screen('FillRect', window, leftRectColor, centeredLeftRect);
            Screen('FillRect', window, rightRectColor, centeredRightRect);

            vbi = Screen('Flip', window, vbi+(waitFrames - 0.5) * ifi); 

            if (xCirCenter+(maxDiameter/2)) >= screenXpixels - baseRightRect(3)
                fprintf('Hit Right\n');
                targetHit = true;
                Hit = [Hit; "right"];
                break;
            elseif ((xCirCenter-(maxDiameter/2)) <= baseLeftRect(3))
                fprintf('Hit Left\n'); 
                targetHit = true;
                Hit = [Hit; "left"];
                break;
            end
        end
        
        TimeSteps = [TimeSteps; frame];

        if targetHit ~= true
            fprintf('Missed target\n');
            Hit = [Hit; "miss"];
        end
        
    % 3 becuase of ++setp
    if (step == 3)
        % Wait for keyboard response
        textString_repeat = [sprintf('Do you want to have another go? If yes press ->, else press esc')];
        rightKey = KbName('RightArrow');
        escapeKey = KbName('ESCAPE');
        respToBeMade = true;

        while respToBeMade == true
            Screen('DrawText', window, textString_repeat, 300, 500, 1, 0, 0);
            % Check the keyboard. The person should press the
            [keyIsDown, secs, keyCode] = KbCheck;
            if keyCode(rightKey)
                respToBeMade = false;
            elseif keyCode(escapeKey)
                continue_with_experiment = false;
                respToBeMade = false;
            end
            % Flip to the screen
            vbi = Screen('Flip', window, vbi + (waitFrames - 0.5) * ifi);
        end
    end

    end

    if (block < n_blocks)
        % Wait for keyboard response
        textString_repeat = [sprintf('Do you want to have another go? If yes press ->, else press esc')];
        rightKey = KbName('RightArrow');
        escapeKey = KbName('ESCAPE');
        respToBeMade = true;

        while respToBeMade == true

            Screen('DrawText', window, textString_repeat, 300, 500, 1, 0, 0);

            % Check the keyboard. The person should press the
            [keyIsDown,secs, keyCode] = KbCheck;
            if keyCode(rightKey)
                respToBeMade = false;
            elseif keyCode(escapeKey)
                continue_with_experiment = false;
                respToBeMade = false;
            end

            % Flip to the screen
            vbi = Screen('Flip', window, vbi + (waitFrames - 0.5) * ifi);
        end
    end
end
fprintf('Experiment Done!!\n');

% Experiment Summary
date_n_time = string(datetime('now','Format','yyyy-MM-dd''T''HHmmss'));
fprintf(date_n_time);
fprintf('\n***********************************\n');
fprintf('********Experiment Summary*********\n');
fprintf('***********************************\n');
summary = table(Trial, Target, Hit, TimeSteps);
disp(summary);
experiment_name = strcat('\experiment_', date_n_time, '.csv');
writetable(summary, strcat(datasetPath, experiment_name),'Delimiter',',','QuoteStrings',true);

a1 = sum(summary.Target == "right" & summary.Hit == "right");
a2 = sum(summary.Target == "right" & summary.Hit == "left");
a3 = sum(summary.Target == "left" & summary.Hit == "right");
a4 = sum(summary.Target == "left" & summary.Hit == "left");

confusion_mat = [a1 a2; a3 a4];
fprintf('\n Confusion Matrix: Target along rows (1: Right, 2: Left), Hit along cols (1: Right, 2: Left)\n');
disp(confusion_mat);

total_trials = size(summary.Trial, 1);
total_correct = a1 + a4;
accuracy = total_correct / total_trials;
fprintf('\n Accuracy: %f\n', accuracy);
fprintf('\n***********************************\n');
fprintf('***********************************\n');

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

clear;
sca;
else
    fprintf('Restart Pegasus to ensure that the files are recorded in a different folder.');
end
    