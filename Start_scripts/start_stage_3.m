fprintf("Stream Started!\n");
fprintf("Waiting 60s before starting classifier\n");
!matlab -r start_stream &
pause(60);
fprintf("Classifier Started!\n");
fprintf("Waiting 20s before starting scenario\n");
!matlab -r start_online_classifier &
pause(20);
fprintf("Experiment running...");
!matlab -r start_scenario &
exit
