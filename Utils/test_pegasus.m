serverName = 'DESKTOP-NSLRRVR';

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

%Identify this program to the server we're connected to.
succeeded = NlxSetApplicationName('Signal_Online_script');
if succeeded ~= 1
    fprintf('FAILED to set the application name\n');
end

command = sprintf('-PostEvent "%s" %d %d', 'right', 192, 1);
while true
    [~, ~] = NlxSendCommand(command);
end
