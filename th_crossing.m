function index = th_crossing(data, threshold, min_interval)
%%
% returns the "indexes" of the data whenever it crosses the threshold
% 2 conditions:
%       (a) previous 2 points are less than threshold
%       (b) previous event is away from the crossing event at least by
%       min_interval (3rd argument)
%
% display: hold on; plot(idx,data(idx),'bo');

if nargin < 3
    min_interval = 2;
end

%% All points which crossed the threshold.
idx = find(data>threshold); % index array. timestamps
idx = idx(idx>3);           % excludes the first two elements.

if isempty(idx)
    index = idx;
    return;
end

%% 1. is it rising?
% condition? previous 2 points should be less than threshold
% access 'data' using idx
rise1 = data(idx-1) < threshold; % rise1 is index array. length(rise1) = length(idx) 
rise2 = data(idx-2) < threshold; 
rise = rise1 & rise2;

%%
idx = idx(rise);
lastevent = idx(1);
for i = 2:length(idx)
    


%% 2. is it sufficiently away from the previous th-crossing event?
% interspacing of events
interevents = zeros(size(idx));
interevents(1) = length(data); % maximum interspacing. The 1st peak has the previous peak infinitely long ago.


interevents(2:end) = idx(2:end) - idx(1:end-1);
isitaway = interevents > min_interval;

index = idx(rise & isitaway);               % collect the index only

end
