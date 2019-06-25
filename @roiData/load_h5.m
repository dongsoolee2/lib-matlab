function load_h5(r, dirpath)

h5files = dir('*.h5');

for i=1:numel(h5files)
    fprintf('%d: %s \n', i, h5files(i).name);
end

ans = input('Which h5 file do you want to open? [1]');

if isempty(ans)
    ans = 1;
end

fname = h5files(ans).name;
fprintf(' ''%s'' was selected.\n', fname);

c = h5info(fname);
att = c.Datasets.Attributes;
numGroups = numel(c.Groups);

for i=1:numGroups
    
    gname = c.Groups(i).Name;
    disp(['Group Name - ', gname]);
    
    stim(i) = c.Groups(i);
    
    for j=1:numel(stim(i).Datasets)
        field_name = stim(i).Datasets(j).Name
        
        stim(i).Datasets(j).Data = h5read(fname, [gname,'/',field_name]);
        
        %stim(i).(field_name) = h5read(fname, [gname,'/',field_name]);
    end
   
end
   
r.stim = stim;
r.stim_att = att;

struct2table(r.stim)
end

function load_h5_bk(r, dirpath)
% load stim data from 'stimulus.h5' in current directory    
    %h5info('stimulus.h5')
    %h5disp('stimulus.h5')
    if nargin < 2
        disp('Looking for h5 file in ..');
        dirpath2 = '/Users/peterfish/Documents/1__Retina_Study/Docs_Code_Stim/Mystim';
        dirpath3 = 'C:\Users\scanimage\Documents\MATLAB\visual_stimulus\logs\19-06-19';
        disp(['1. Current dir = ', pwd]);
        disp(['2. ', dirpath2]);
        disp(['3. ', dirpath3]);
        n = input('Which dir do you want to search stimulus.h5? [1]: ');
        if isempty(n)
            n = 1;
        end
        switch n
            case 1
                dirpath = pwd;
            case 2
                dirpath = dirpath2;
            case 3
                dirpath = dirpath3;
            otherwise
        end
    end

    fname = [dirpath, '/stimulus.h5']; 
    if ~exist(fname, 'file')
        disp('no file for /stimulus.h5.');
        return;
    end

    % stim id for whitenoise?
    h5disp(fname);
    a = h5info(fname);

    % Assuption: Group /expt1 is a whitenoise stimulus.
    disp('Assumption: group /expt1/ (among several) is a whitenoise stimulus. Load /expt1/.'); % new function for /expt2 is needed.
    stim = h5read([dirpath, '/stimulus.h5'], '/expt1/stim');
    times = h5read([dirpath, '/stimulus.h5'], '/expt1/timestamps');

    % /Datasets (Name: /disp) 
    if contains(a.Datasets.Attributes.Name, 'aperturesize_whitenoise_mm')
        whitenoise_size = h5readatt([dirpath, '/stimulus.h5'], '/disp', 'aperturesize_whitenoise_mm');
    else
        whitenoise_size = NaN;
    end
    if contains(a.Datasets.Attributes.Name, 'aperturesize_mm')
        aperture_size = h5readatt([dirpath, '/stimulus.h5'], '/disp', 'aperturesize_mm');
    else
        aperture_size = NaN;
    end
    fprintf('Aperture size [mm]: %.3f, Whitenoise aperture size [mm]: %.3f\n', aperture_size, whitenoise_size);

    %
    r.get_stimulus(stim, times, whitenoise_size);
    disp('Whitenoise stimulus info has been loaded.');

    % select_data ?
end