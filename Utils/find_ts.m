subject = 'car13';

event_begin_record = 399360;
anchor_record = 390144;
anchor_ts = 1551732748001407;

event_ts = anchor_ts + ((event_begin_record - anchor_record) * 1e6 / 2000);
fprintf("%d\n", event_ts);

% 1551732752609407
