function h = interpret_SI_header_from_TiffReader(t, size_vol)
% inputs: 
%
h = [];

% general status
% SI.extTrigEnable = false
h = get_str_to_new_field(h, t, 'extTrigEnable', []); 

% channel parameters
h = get_digit_numbers_to_new_field(h, t, 'channelSave', [1]);
h.n_channelSave = numel(h.channelSave);
if h.n_channelSave == 0
    error('No saved channel? # of channel saved is 0.');
end

% beam parameters
h = get_float_number_to_new_field(h, t, 'hBeams.powers', []);

% scan parameters
h = get_float_number_to_new_field(h, t, 'scanZoomFactor',  []);
h = get_float_number_to_new_field(h, t, 'scanFramePeriod', []);
h = get_float_number_to_new_field(h, t, 'scanFrameRate',   []);
h = get_float_number_to_new_field(h, t, 'linesPerFrame',   []);
h = get_float_number_to_new_field(h, t, 'pixelsPerLine',   []);
h = get_float_number_to_new_field(h, t, 'logFramesPerFile',[]);
h = get_float_number_to_new_field(h, t, 'logAverageFactor',[]);
h.logFramePeriod = h.scanFramePeriod * h.logAverageFactor;
h.logFrameRate   = h.scanFrameRate / h.logAverageFactor;

% check scanFramePeriod precision.
str_line = get_line(t, 'scanFramePeriod'); 
disp([str_line,' (saved in Scanimage header file)']);
fprintf('scanFramePeriod = %.7f (imported number)\n', h.scanFramePeriod);
fprintf(' logFramePeriod = %.7f (imported number)\n',  h.logFramePeriod);

% stack parameters
h = get_float_number_to_new_field(h, t, 'numSlices', 1); % not actual slice numbers in stored file
h = get_float_number_to_new_field(h, t, 'framesPerSlice', []);
% h = get_float_number_to_new_field(h, t, 'framesPerSlice', h.n_frames/h.numSlices);
% if (h.framesPerSlice - floor(h.framesPerSlice)) > 0
%     fprintf('\nTotal frame numbers (%d) are not divisible by numSlices (%d).\n', h.n_frames, h.numSlices);
% end
h = get_float_number_to_new_field(h, t, 'stackZStepSize', []);
h = get_digit_numbers_to_new_field(h, t, 'zs', []);
h.logFramesPerSlice = h.framesPerSlice / h.logAverageFactor;

% Motor parameters: need to be updated !!!
h = get_digit_numbers_to_new_field(h, t, 'motorPosition', []);
h = get_digit_numbers_to_new_field(h, t, 'motorPositionTarget', []);

if nargin > 1
    if length(size_vol) < 3
        disp('vol (data) has no frame dimension.');
        n_frames = 1;
    else
        n_frames = size_vol(3);
    end
    %
    h.n_frames = n_frames;
    h.n_frames_ch = n_frames/h.n_channelSave;
    
    if rem(n_frames, h.n_channelSave)
        disp('Total frame number is not divisible by channel number saved.');
    end
    
    if isempty(h.logFramesPerSlice)
        h.logNumSlices = [];
        disp('logFramesPerSlice was not defined.');
    else
        h.logNumSlices = floor(h.n_frames_ch / h.logFramesPerSlice);                
    end
end
disp(' ');

end

function h = get_float_number_to_new_field(h, text, str, default_value)
% inputs:
%           h - header struct. Should be predefined. 
% search 'str' in 'text' file and add the float number as a new field of the struct 'h' 

num = get_float_number_after_str(text, [str,' = ']);

if isempty(num)
    num = default_value;
end

% exclude any other characters.
%str = str(isletter(str));

str = strrep(str,'.','_');

h.(str) = num; 

end

function h = get_str_to_new_field(h, text, str, default_value)
% inputs:
%           h - header struct. Should be predefined. 
% search 'str' in 'text' file and add the value as a new field of the struct 'h' 

value = get_str_after_str(text, [str,' = ']);

if isempty(value)
    value = default_value;
end

str = strrep(str,'.','_');

h.(str) = value; 

end


function h = get_digit_numbers_to_new_field(h, text, str, default_value)
% search 'str' in 'text' file and add the float number as a new field of the struct 'h' 

s = get_line(text, str);
a = extract_numbers(s);

if isempty(a)
    a = default_value;
end

h.(str) = a; 

end

function str_line = get_line(text, str)
% get the line from the text
% inputs:
%   text
%   str

loc = strfind(text, str);
str_lines = splitlines(text(loc:end));
str_line = str_lines{1};

end

function a = get_float_number_after_str(text, str)
% get the line from the text
% inputs:
%   text
%   str

loc = strfind(text, str);
str_lines = splitlines(text(loc:end));
str_line = str_lines{1};

a = sscanf(str_line, [str, '%f']); % precision is enough?

if isnumeric(a)
    % do nothing
else
    disp(['No property or numeric value for the metadata: ', str]);

end

end

function a = get_str_after_str(text, str)
% get str property value from the text
% inputs:
%   text
%   str

loc = strfind(text, str);
str_lines = splitlines(text(loc:end));
str_line = str_lines{1};

a = sscanf(str_line, [str, '%s']);

if ischar(a)
    % do nothing
else
    disp(['No string value for the metadata: ', str]);
end

end

function B = extract_numbers(A)

B = regexp(A,'\d*','Match'); % digits. not for float.
B = str2double(B);
%C = regexp(A,'[0-9]','match');
%disp(C);

% for i= 1:length(B)
%   if ~isempty(B{i})
%       Num(i,1)=str2double(B{i}(end));
%   else
%       Num(i,1)=NaN;
%   end
% end

end