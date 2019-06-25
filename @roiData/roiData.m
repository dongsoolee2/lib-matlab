classdef roiData < matlab.mixin.Copyable
% Given cc, extract roi-avg traces from vol data.
% bg remove, bandpass filtering, normalize raw traces.
% If trigger-times are given, trial-avg will be computed.
% If whitenoise stim and fliptimes are given, linear RF will be computed.
%
% Constructor input: 
%        vol - 3-D matrix. Single channel. (Each channel might have
%        different ROI.)
%    
    properties
        ex_name
        header      % Imaging condition
        image       % mean (or primary) image (over snaps).
        snap_ref    % reference snap for no shift case. 
        snaps       % snaps for every major events
        snaps_trigger_times % Currently, session trigger times.
        snaps_middle_times % times for snap images
        ex_stim     % Stim parameters struct
        %
        roi_cc      % roi information (struct 'cc')
        roi_cc_time % time in which the given cc is best aligned.
        %
        roi_patch       % representative zoomed ROI image
        roi_shift       % x & y drift [px] of each ROI in each frame time by interpolating snaps' shifts.
        roi_shift_snaps % x & y drift [px] of each ROI between snap images.
        %
        ifi         % inter-frame interval of vol (data)
        stim_trigger_times % Absolute times when stims (or PD) were triggered. Fine triggers.
        sess_trigger_times % Absolute times of session (or major) triggers. Should be a subset of stim_triggers, but the value can be a little off from it.
        sess_trigger_ids   % Session triggers as ids of stim_trigger_times. Used in select_data().
        stim_end    % End time of stimulus. Last avg_trigger_time + interval. 
        %
        stim_movie
        stim_fliptimes     % relative times between whitenoise flip times. Should start from 0.
        stim_size          % spatial size [mm]
        stim_disp          % stimulus disp params
        %
        numFrames
        numRoi
        
        % times = r.f_times
        f_times         % frame times
        traces          % Libraries of roi traces with all possible integer shifts.
        traces_xlist    % x integer list for traces
        traces_ylist    % y integer list for traces
         bg_trace       % trace of background (detect non-fluorecent pixels by thresholding)
        roi_trace       % raw trace (bg substracted. No other post-processing)
        roi_smoothed    % smoothed raw trace
        roi_smoothed_norm    % baseline substracted and normalized by it again. dF/F.
        
        % times = r.f_times_norm
        roi_smoothed_detrend % trend substracted
        roi_smoothed_detrend_norm % norm by trend. dF/F
        roi_filtered    % lowpass filtered
        roi_trend       % trend for normalization. Very lowpass filter used. 
        roi_baseline    % baseline fluorescence level (usually right before stimulus)
        roi_filtered_norm % dF/F @ dF = filtered - detrended, F = detrended_trace
        %
        ignore_sec      % ignore first few secs for filtering. SHould be updated before updateing filtering. (default: until 1st trigger)
        f_times_fil     % Times for all traces except raw and smoothed traces.
        f_times_norm    % Currently, same as f_times_fil.
        
        % statistics
        stat
        p_corr % between repeats ['.smoothed', '.smoothed_norm']. Only available for avg analysis.
               % computed @ updated_smoothed_trace 
        
        % smoothing params
        smoothing_method = 'movmean';
        smoothing_size  
        smoothing_size_init = 5;
                
        % params:  Norm. (or Nyquist) freq. 
        w_filter_low_pass  = 0.4 
        w_filter_low_stop  = 0.6
        w_filter_trend_pass 
        w_filter_trend_stop 
        
        % Average analysis parameters
        % (subset of stim minor triggers --> avg_trigger_times --> aligning data (align_trace_to_avg_triggers) 
        % --> average analysis)
        avg_FLAG = false
        avg_FIRST_EXCLUDE = false
        avg_every         % Spacing of stim triggers for average analysis (avg_tigger_times)
        avg_trigger_times % Times for aligning between trials for average analysis. 
                          % A subset of stim_trigger_times.
                          % Can be directly given or given by set.avg_every method.
        avg_trigger_interval
        avg_duration    % duration for average analysis
        avg_stim_times  % stim times within one avg trace [0 duration]
        avg_stim_plot   % structure for plot properties of each stim triggers.
        avg_stim_tags
        
        % avg traces (always smoothed at least)
        avg_trace       % avg over trials. SMOOTHED. (times x roi#): good for 2-D plot
        avg_trace_norm  % Normed and centered. SMOOTHED trace. No more use?
        avg_trace_fil   % avg over (filtered) trials.
        avg_trace_smooth_norm
        %avg_trace_filter_norm
        avg_trace_std   % std over trials
        %avg_trace_filter_norm
        avg_projected   % projected trace onto (PCA) space.
        avg_pca_score   % roi# x dim
        avg_times   % times for one stim cycle
        a_times     % times for avg plot. Full cycles (e.g. 2 cycles). Phase shifted.
        
        % whitenoise responses
        rf              % cell arrays
        
        % clusters for ROIs
        dispClusterNum = 10;
        totClusterNum = 100;
        c             % cluster id array. 0 is unallowcated or noisy group
        c_mean        % cluster mean for average trace (trace X #clusters ~100). update through plot_cluster
        c_hfig
        c_note
        roi_review
        roi_selected
        roi_good % selected ids for good cells (e.g. high correlation over repeats) 
        
        % Properties for plot of averaged trace. (use traceAvgPlot ?? not any more?)
        % Method 'align_trace_to_avg_triggers' will use those properties.
        n_cycle = 1.5
        s_phase = -0.25 % Shift phase toward negative time direction. 1 means one full cycle.
        t_range = [-100, 100] % Currently, limits the range of trigger line plots.
        %c_range = [0, 1]; % Cycle range. Not used yet. 
        coeff   % (PCA) basis
    end
 
    properties (Hidden, Access = private)
        stim_trigger_interval % if triggers are irregular, meaningless. Do not use it.
        % old names
        stim_times      % (= stim_trigger_times)
        stim_duration   % stim trigger interval
        s_times         % single trial times
        roi_normalized  % (= roi_filtered_norm) dF/F @ dF = filtered - detrended, F = detrended_trace
        stim_whitenoise
    end
    
    methods
        
        function  rr = select_data(r, stim_ids, trigger_type)
            % Given stim trigger ids (not avg repeat triggers), create new instance of roiDATA
            % stim trigger times id. (e.g. [2, 3, 4])
            % trigger id = 0 means from the first data point.
            % avg triggers should be a subset of stim ids.
            if nargin < 3
                trigger_type = 'sess';
                disp('(select_data) Trigger_type: session (major) triggers.');
            end
            
            if nargin < 2
                error('Trigger ids (default: session triggers) must be given as a variable (e.g. 6:10).');
            end
            
            rr = copy(r);
            
            % Trigger type
            switch trigger_type
                case 'sess'
                    % start stim trigger id
                    if stim_ids(1) == 0
                        init_stim_trigger_id = 0;
                    else    
                        init_stim_trigger_id = r.sess_trigger_ids(stim_ids(1));
                    end
                    % end stim trigger id
                    if stim_ids(end) == numel(r.sess_trigger_times)
                        % last session.
                        end_stim_trigger_id = numel(r.stim_trigger_times);
                    else
                        % not last sessoin.
                        next_session_stim_trigger_id = r.sess_trigger_ids( stim_ids(end) + 1 );
                        end_stim_trigger_id = next_session_stim_trigger_id - 1;
                    end
                    % range as stim trigger ids
                    stim_ids = init_stim_trigger_id:end_stim_trigger_id;
                case 'stim'
                    
                otherwise
            end
            
            % Time range
            if stim_ids(1) == 0
                t_init = 0.;
                disp('Stim trigger id 0: start t = 0.');
                % exclude id =0
                stim_ids = stim_ids(2:end);
            else
                t_init = rr.stim_trigger_times( stim_ids(1) );
            end
            
            % Is the ending index the last trigger?
            if stim_ids(end) >= length(rr.stim_trigger_times)
                t_end = rr.f_times(end);
            else 
                t_end = rr.stim_trigger_times( stim_ids(end)+1 );
            end
            
            % Select data for [t_init, t_end]
            ids = (rr.f_times>=t_init) & (rr.f_times<=t_end); 
            rr.roi_trace = rr.roi_trace(ids, :);
            rr.f_times   = rr.f_times(ids) - t_init; % frame times
            rr.stim_end = rr.f_times(end);
            
            % Shift 'stim trigger times'
            rr.stim_trigger_times = rr.stim_trigger_times(stim_ids); 
            rr.stim_trigger_times = rr.stim_trigger_times - t_init;
            
            % Shift igonre_sec 
            rr.ignore_sec = rr.stim_trigger_times(1);           
            
            % Avg triggers every N stim triggers for new instance?
            if r.avg_FLAG
                str_input = sprintf('Stim trigger events: %d.\nAvg over every N triggers? [Default N = %d (%s)]',...
                                length(stim_ids), r.avg_every, r.ex_name);
                n = input(str_input);
                if isempty(n)
                    n = r.avg_every; % case default number
                end
                % set avg_every (set.avg_every)
                rr.avg_every = n; % include trace updating.
            else
                % update only
                rr.update_smoothed_trace;
            end
        end
        
        function load_ex2(r, ex)
            % Read 'ex' structure and interpret it. Old version.
            % interpret if middle line is preffered for plot for each stim type.
            disp('This is old version. Use version1');
            
            if iscell(ex.stim)
                stim = [ex.stim{:}];
            else
                stim = ex.stim;
            end
            % name tags as cell array
            i = 1; % id for trigger events
            k = 1; % id for stim struct
            while i <= r.avg_every
                if isfield(stim(k),'cycle') && ~isempty(stim(k).cycle)
                    cycle = stim(k).cycle;
                else
                    cycle = 1;
                end
                ids = (1:cycle) + (i-1);
                r.avg_stim_tags(ids(1)) = {stim(k).tag};
                i = max(ids) + 1;
                k = k + 1; % next stim tag
            end
            if k-1 == length(stim)
                fprintf('All (k=%d) stim tags were scanned and aligned with num of stim triggers.\n', k-1);
            elseif k-1 < length(stim)
                fprintf('Stim tigger lines are more than # of stim tags.\n');
            end
        end
        
        function load_ex1(r, ex)
            % Read 'ex' structure and interpret it.
            % Loop over ex.stim.
            r.ex_stim = ex;
%             if isfield(ex, 'n_repeats') && ~isempty(ex.n_repeats) 
%                 n_repeat = ex.n_repeats;
%             end
%           
            if isempty(ex)
                return;
            end
            
            if iscell(ex.stim)
                stim = [ex.stim{:}];
            else
                stim = ex.stim;
            end

            i = 1; % id for trigger events
            
            for k = 1:numel(stim)
                % conditions according to tag name
                switch stim(k).tag
                    case 'blank'
                        r.avg_stim_plot(i).middleline = false;
                    case ' '
                        r.avg_stim_plot(i).middleline = false;
                    otherwise
                        r.avg_stim_plot(i).middleline = true;
                end
                % cycle
                if isfield(stim(k),'cycle') && ~isempty(stim(k).cycle)
                    cycle = stim(k).cycle;
                else
                    cycle = 1;
                end
                
                % conditions according to phase in 1st cycle.
                tag_shift = 0;
                if isfield(stim(k),'phase_1st_cycle') && ~isempty(stim(k).phase_1st_cycle) % constatnt phase over the first cycle.
                    r.avg_stim_plot(i).middleline = false;
                    if cycle > 1
                        tag_shift = 1;
                    end
                end
                % display tag     
                r.avg_stim_tags(i + tag_shift) = {stim(k).tag};
                r.avg_stim_plot(i + tag_shift).tag = stim(k).tag;
                %   
                i = i + cycle;
            end
            
            if i-1 == r.avg_every
                fprintf('All stim tags (k=%d) were scanned and aligned with num of %d stim trigger times (registered by PD).\n', k-1, r.avg_every);
            elseif i-1 < r.avg_every
                fprintf('Stim tigger lines are more than # of stim tags. Make sure how many triggers are supposed to be in one stim repeat. Please load ex again. \n');
            elseif i-1 > r.avg_every
                fprintf('Stim tigger lines are less than # of stim tags. Make sure how many triggers are supposed to be in one stim repeat. Please load ex again. \n');
            end
        end
        
        function load_h5(r, dirpath)
        % load stim data from 'stimulus.h5' in current directory    
            %h5info('stimulus.h5')
            %h5disp('stimulus.h5')
            if nargin < 2
                disp('Looking for h5 file in ..');
                dirpath2 = '/Users/peterfish/Documents/1__Retina_Study/Docs_Code_Stim/Mystim';
                dirpath3 = 'C:\Users\scanimage\Documents\MATLAB\visual_stimulus\logs\18-06-22';
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
        
        function save(r)
            % struct for save
            % roi info
            s.cc = r.roi_cc;
            % avg plot info
            %s.avg_stim_tags = r.avg_stim_tags;
            s.avg_stim_plot  = r.avg_stim_plot;
            s.avg_stim_times = r.avg_stim_times;
            s.stim_trigger_times = r.stim_trigger_times;
            s.sess_trigger_times = r.sess_trigger_times;
            % cluster info
            s.c = r.c;
            s.c_note = r.c_note;
            s.roi_review = r.roi_review;
            % stim ex
            s.ex_stim = r.ex_stim;
            save([r.ex_name,'_roiData_save'], '-struct', 's');
        end
        
        function load_c(r, c, c_note, roi_review)
            % load cluster info
            r.c = c;
            r.c_note = c_note;
            r.roi_review = roi_review;
        end
        
        function reset_cluster(r)
            %[row, col] = size(r.c);
            r.c = zeros(size(r.c));
            r.c_mean = zeros(size(r.c_mean));
            r.c_note = cell(size(r.c_note));
            r.roi_review = [];
        end
        
        function set.c(r, value)
            n_prev = numel(find(r.c~=0));
            r.c = value;
            r.totClusterNum = max(r.c);
            n_new = numel(find(r.c~=0));
            if n_new ~= n_prev
                % c_mean (avg trace) update
                for i = 1;r.totClusterNum
                    y = r.avg_trace(:, r.c==i);
                    y = normc(y);               % Norm by col
                    y = mean(y, 2);
                    % Mean substraction and normalization might be needed.
                    r.c_mean(:,i) = y;
                end
                % pca update
                r.pca;
                disp('PCA score has been computed.');
            end
        end
        
        function swapcluster(r, i, j)
            note_temp = r.c_note{i};
            i_idx = (r.c == i);
            j_idx = (r.c == j);
            % switch note
            r.c_note{i} = r.c_note{j};
            r.c_note{j} = note_temp;
            % switch index
            r.c(i_idx) = j;
            r.c(j_idx) = i;
        end
            
        function myshow(r)
            J = myshow(r.image);
        end
        
        function imvol(r)
            imvol(r.image, 'title', r.ex_name, 'roi', r.roi_cc, 'edit', true, 'scanZoom', r.header.scanZoomFactor); % can be different depending on threhsold 
        end
        
        function get_stimulus(r, stims_whitenoise, fliptimes, aperture_size)
            if nargin > 3
                r.stim_size = aperture_size;
                if isempty(r.stim_size)
                    disdp('Stim_size is still empty.');
                end
            end
            % for whithenoise stim
            r.stim_movie = stims_whitenoise;
            r.stim_fliptimes = fliptimes;
        end
        
        function set.smoothing_size(r, t)
            if nargin < 2
                t = r.smoothing_size_init;
            end
            r.smoothing_size = t;
            r.update_smoothed_trace;
            r.average_analysis;
        end
        
        function set.w_filter_low_pass(r, w)
            r.w_filter_low_pass = w;
            r.update_smoothed_trace;
            r.average_analysis;
        end
        
        function set.w_filter_low_stop(r, w)
            r.w_filter_low_stop = w;
            r.update_smoothed_trace;
            r.average_analysis;
        end
                    
        %% Constructor
        function r = roiData(vol, cc, ex_str, ifi, stim_trigger_times, stim_movie, stim_fliptimes)
            % vol: 3-D image stack data
            % ifi: inter-frame interval or log-frames-period
            if nargin > 0 % in order to create an array with no input arguments.
                disp('roiData..');
                r.roi_cc = cc;
                r.numRoi = cc.NumObjects;
                r.numFrames = size(vol, 3);
                r.roi_trace    = zeros(r.numFrames, r.numRoi);
                r.roi_smoothed = zeros(r.numFrames, r.numRoi);
                r.rf = cell(1, r.numRoi);
                %
                if nargin < 5 
                    stim_trigger_times = 0;
                end
                %
                if nargin < 4
                    ifi = 1;
                end
                %
                if nargin < 3
                    ex_str = [];
                end
                %
                r.ex_name = ex_str;
                r.ifi = ifi;
                r.f_times = ((1:r.numFrames)-0.5)*ifi; % frame times. in the middle of the frame
                % Final time 
                r.stim_end = r.f_times(end); 
                % stim_end time will be finely adjusted by assigning avg_trigger_times.
                % stim_end will be used for computing statistics.
                
                % Background PMT level in image stack (vol)
                % PMT-amp output level for with no activity.    
                % PMT-amp output level for dark count activity.
                % --> Take 0.5% lowest pixels of mean image.
                % --> or prepare multiple bg traces as varing percentages.
                a = sort(vec(vol(:,:,1))); % 1st frame activity.
                N = ceil(size(vol, 1)/10);
                bg_PMT = mean(a(1:(N*N))); % PMT level for with no activity.    
                fprintf('Background PMT level was estimated to be %.1f.\n', bg_PMT);

                %% Import stimulus trigger information: Average analysis and Define snap images
                % stim_triger_times can be a cell array
                % {1} : events1 - Major events. ~ sess_trigger_times
                % {2} : events2 - Finer evetns. ~ stim_trigger_times
                % {3} : ...
                % or simple array.
                if iscell(stim_trigger_times) % since 2018 Aug.
                    switch numel(stim_trigger_times)
                        case 2 
                            r.stim_trigger_times = stim_trigger_times{2}; % minor trigger events
                            r.sess_trigger_times = stim_trigger_times{1}; % major trigger events
                            
                        otherwise
                            r.stim_trigger_times = stim_trigger_times{1};
                            r.sess_trigger_times = stim_trigger_times{1};
                            disp('The first cell array of stim_trigger_times was set as both session and stim trigger times.');
                    end
                else
                    % not cell array.
                    r.stim_trigger_times = stim_trigger_times;
                    r.sess_trigger_times = stim_trigger_times;
                end
                numStimTriggers = numel(r.stim_trigger_times);
                numSessTriggers = numel(r.sess_trigger_times);
                fprintf('%d session (major) triggers, %d stim (minor) triggers are given.\n', numSessTriggers, numStimTriggers);
                % Num of stim triggers within one session on
                % average
                %n = floor(numStimTriggers/numSessTriggers);
                
                %%
                [rows, cols, nframes] = size(vol);
                
                %% reshaped vol
                vol_reshaped = reshape(vol, [], nframes);
                
                %% Snap images (at sess_trigger_times)
                r.snaps_trigger_times = r.sess_trigger_times;
                [r.snaps, r.snaps_middle_times] = utils.mean_images_after_triggers(vol, r.f_times, r.snaps_trigger_times, 15); % mean of 15s duration at times of..
                
                % mean over snaps
                r.image = mean(r.snaps, 3);
                
                % Add last snap.
                [lastSnap, lastSnapTime] = utils.mean_image_last_duration(vol, r.f_times, 15);
                if lastSnapTime > r.snaps_middle_times(end)
                    r.snaps = cat(3, r.snaps, lastSnap);
                    r.snaps_trigger_times = cat(2, r.snaps_trigger_times, lastSnapTime - (r.f_times(end)-lastSnapTime));
                    r.snaps_middle_times = cat(2, r.snaps_middle_times, lastSnapTime);
                end

                % Timestamp of given cc
                if isfield(cc, 'timestamp')
                    r.roi_cc_time = cc.timestamp;
                elseif isfield(cc, 'i_image')
                    i_snap = cc.i_image;
                    % assume i-th snap corresponds to i-th session trigger.
                    str = sprintf('Is given cc best agliend with the snap image triggered at session trigger %d (%.1f sec)? [Y]', i_snap, r.snaps_trigger_times(i_snap));
                    answer = input(str, 's');
                    if isempty(answer) || contains(str, 'Y')  || contains(str, 'y')
                        r.roi_cc_time = r.snaps_middle_times(i_snap);
                    end
                else
                    % time for offset x, y = 0.
                    r.roi_cc_time = input('Enter time in which the roi cc is aligned (sec): ');
                end
                
                % Pick one of the middle snap for reference roi images.
                i_ref_snap = max(1, round(length(r.snaps_middle_times)/2.));
                % or find a closest snap to roi_cc_time..
                r.snap_ref = r.snaps(:,:,i_ref_snap); % arbitrary choice 
                
                % Representative ROI patch
                padding = 10;
                r.roi_patch = utils.getPatchesFromPixelLists(r.snap_ref, cc.PixelIdxList, padding);
                
                %% Estimate shift (x, y) of individual ROIs across snap images
                % Image correlation between snaps to compute offset x, y
                % (It has no meaning in an absolute sense. Relative dist from ref-image which is arbitrary choice.)
                r.roi_shift_snaps = utils.roi_shift_from_ref(r.snap_ref, r.snaps, cc.PixelIdxList, 1:r.numRoi, padding); %% cc is needed just for patch location.
               
                % Interpolate x,y of each roi for all frame times
                % (roi_shift will be updated)
                r.roi_shift_xy_interpolation;
                
                %% roi traces with x,y shifts of possible integer grid
                r.traces = cell(1, r.numRoi);
                
                %% Library of roi mean traces (must be in constructor)
                for k = 1:r.numRoi
                        
                    % r.traces{roi}(values, x_index, y_index)
                    r.traces{k} = zeros(r.numFrames, r.roi_shift.xnum, r.roi_shift.ynum);
                    
                    for i = 1:length(r.traces_xlist)
                    for j = 1:length(r.traces_ylist)
                        
                        x = r.traces_xlist(i);
                        y = r.traces_ylist(j);
                        offset = [x, y];
                        shiftedPixelIdxList = utils.getShiftedPixelList(cc.PixelIdxList{k}, offset, rows, cols);
                        
                        % compute mean signal for the new pixel list
                        % (shifted ROI)
                        trace_shifted = mean(vol_reshaped(shiftedPixelIdxList, :), 1);
                        trace_shifted = trace_shifted - bg_PMT; % No-activity PMT level substraction
                        
                        r.traces{k}(:,i,j) = trace_shifted;
                    end
                    end
                    
                end
                
                %% Default roi trace: no-shift conditions
                for i=1:r.numRoi
                    y = mean(vol_reshaped(cc.PixelIdxList{i},:),1);
                    y = y - bg_PMT;       % No-activity PMT level substraction
                    r.roi_trace(:,i) = y; % raw data (bg substracted)
                    
                    % estimating roi trace under dynamic trajectories
                    %r.roi_trace(:,i) = roitrace(vol_reshaped, cc.PixelIdxList{i}, x, y);  
                end
                disp('ROI traces were extracted. PMT bg level was substracted..');
                
                % Interpolation of trajectories across times of snaps.
                %r.roi_shift_xy_interpolation;
                
                %% Dynamic ROI mode
                % roi mean with shifted trajectories
                
                % Trajectories of rois: (x, y)
                % Interpolating roi mean as a function of x & y from trace
                % libraries.
%                 for i=1:r.numRoi
%                     r.roi_trace(:,i) = r.roi_trace_interpolated(i);
%                 end
%                 
                %% Estimate BG trace (for cross-talk and timing inspection)
                % Non-fluorecence bg pixels = pixels of the low-end c% excluding pixels in
                % predefined cc.
                % Defined in the constructor since vol_reshaped will not be
                % stored in roiData.
                cc_pixels = cc_to_bwmask(cc); % roi pixels (logical)
                contrast = [0.5 1.0 2.0 4.0];
                r.bg_trace = zeros(nframes, length(contrast));
                for i = 1:length(contrast) % contrast values (%)
                    c = contrast(i);
                    bw1 = lowerpixels(r.snaps(:,:,1), c);
                    bw2 = lowerpixels(r.snaps(:,:,end), c);
                    bw = bw1 & bw2 & ~cc_pixels;
                    r.bg_trace(:,i) = mean(vol_reshaped(bw,:), 1);
                end
                % plot bg trace if needed.
%                 figure; 
%                 plot(r.f_times, r.bg_trace); 
%                 r.plot_stim_lines;
%                 title('Trace of bg pixels excluding roi regions.');  
                %xlim([r.stim_trigger_times(1) - 10, r.stim_end]); 
                
                
                %% Average analysis setting (currently, use default setting)
%                 r.n_cycle = 1.5;
%                 r.s_phase = -0.25;
                
                %% Average analysis
                r.average_trigger_set_by_session_triggers
               
                %% Load ex struct?
                
                %% Cluster mean initialization (100 clusters max)
                r.c_mean = zeros(length(r.a_times), r.totClusterNum);
                      
                % whitenoise stim?
                if nargin > 5
                    r.stim_movie = stim_movie;
                    r.stim_fliptimes = stim_fliptimes;
                elseif contains(r.ex_name, 'whitenoise')
                    r.load_h5;
                    % stim size?
                    if isempty(r.stim_size) || (r.stim_size == 0)
                        r.stim_size = input('Stim size for whitenoise stim? [mm]: ');
                    end
                end

                % cluster parameters
                r.c = zeros(1, r.numRoi);
                r.c_note = cell(1, 100);
                r.c_hfig = [];
                r.roi_review = [];
                
                %% Statistics
                % mean fluorescence level
                r.stat.mean_start = mean( r.roi_trace( r.f_times < 10, :), 1); % mean over first 10s
                if ~isempty(r.stim_trigger_times)
                    %r.stat.mean_f is an old name of mean_stim.
                    r.stat.mean_stim = mean( r.roi_trace(r.f_times > r.stim_trigger_times(1) & r.f_times < r.stim_end, :), 1); % mean during stimulus. ~ baseline?
                    r.stat.mean_baseline = r.roi_baseline;
                end
                
                %% Statistics under identical stimulus if possible.
                numCell = 12; % Print top 10 cells.
                % Plot several (avg) traces
                if r.avg_FLAG == true 
                    % ROIs exhibiting hiested correlations between traces
                    % under repeated stimulus
                    [corr, good_cells] = sort(r.p_corr.smoothed_norm, 'descend');
                    r.roi_good = good_cells;
%                     % Print corr results for top cells
%                     for i = 1:numCell
%                         fprintf('ROI%4d: corr between trials %5.2f\n', good_cells(i), corr(i));
%                     end
                    
                    % plot                    
                    r.plot_repeat;
                    print([r.ex_name, '_plot_repeats'], '-dpng', '-r300');
%                     make_im_figure;
%                     r.plot_roi(good_cells(1:numCell));
                else
                    % single trial case 
                    [mean_f, good_cells] = sort(r.stat.mean_stim, 'descend');
                    r.roi_good = good_cells;
                    % summary
                    fprintf('ROI %d: mean fluorescence level %5.2f\n', good_cells(1:numCell), mean_f(1:numCell));

                    % plot
%                     r.roi_good = good_cells;
%                     r.plot(r.roi_good);
%                     print([r.ex_name, '_plot'], '-dpng', '-r300');
                end
                
                % save 'cc' whenever roiData is created. 
                r.save;
            end
        end
              
                        
        function triggers = stim_triggers_within(r, sess_id)
            % Returns minor stim trigger times under session trigger id.
            
            n_session = numel(r.sess_trigger_times);
            
            if isempty(sess_id)
                str = sprintf('There are %d session triggers. Which session do you want to get for stim triggers? 1-%d [%d]\n', n_session, n_session, n_session); 
                sess_id = input(str);
                if isempty(sess_id); sess_id = n_session; end
            end
            
            % session on and off times.
            session_on  = r.sess_trigger_times(sess_id);
            if sess_id < n_session
                session_off = r.sess_trigger_times(sess_id+1);
                % 
            else
                session_off = r.f_times(end);
            end
            % triggers during the session
            triggers = r.stim_trigger_times(r.stim_trigger_times >= session_on);
            %triggers = [session_on; triggers(:)]; % add the session_on time.
            triggers = triggers(triggers < session_off);
        end
        
        function baseline(r)
            % Estimate baseline of the ROI (fluorecence) signal just before stimulus.
            % Usually, called by avaerage anlaysis.
            % 2019 0313 wrote.
            % 2019 0315 prepare_duration added.
            prepare_duration = 5; %secs. skip during this period.
            duration = 5; %sec
            
            r.roi_baseline = zeros(1, r.numRoi);
            
            if isempty(r.avg_trigger_times)
                disp('No avg trigger time. Baseline level was estimated by the first 5s imaging.');
                id = r.f_times < duration;
            else
                % Data index for 5s before the 1st stim trigger.
                upper = r.f_times < (r.avg_trigger_times(1) - prepare_duration);
                lower = r.f_times > (r.avg_trigger_times(1) - prepare_duration - duration); % 5 sec
                id = upper & lower;
            end
            r.roi_baseline = mean( r.roi_trace(id, :), 1);
            
            % update trace
            r.update_smoothed_trace;
        end
        
        function set.avg_every(r, n_every)
            % Every among stim_trigger_times which is usually given by PD triggers. 
            if n_every == 0
                r.avg_every = 0;
                r.avg_FLAG = false;
                disp('Average analysis OFF..');
                return;
            end
            %
            r.avg_FLAG  = true;
            r.avg_every = n_every;
            disp('Average analysis ON..');

            % Assign triggers for avg analysis: 'avg_trigger_times'
            % Set method for 'avg>trigger_times' should do every jobs for
            % avg analysis.
            if r.avg_every > 1 
                id_trigger = mod(1:numel(r.stim_trigger_times), r.avg_every) == 1; % logical array
                r.avg_trigger_times = r.stim_trigger_times(id_trigger);
            else
                r.avg_trigger_times = r.stim_trigger_times;
            end

            % What's in Set method for 'avg_trigger_times'?
            % 'update_smoothed_trace' method.
            % Given avg_trigger_times and avg_trigger_interval, 
            % update traces. p_corr is computed.
            
            % Stimuli within one cycle.
            % One session can be consisted of multiple stimuli.
            % stim events within one avg period
            r.avg_stim_times = r.stim_trigger_times(1:r.avg_every) - r.stim_trigger_times(1);

            % cell array for tags
            r.avg_stim_tags = cell(1, n_every);
            % struct for the plot properties of each stim trigger time
            r.avg_stim_plot = struct('tag', [], 'middleline',[], 'shade', []);
            r.avg_stim_plot(n_every) = r.avg_stim_plot; % struct array
                [r.avg_stim_plot(:).middleline] = deal(true);
                [r.avg_stim_plot(:).shade]      = deal(false);
        end
        
        function set.avg_trigger_times(r, new_times)
            % THE FINAL information for avaerage analysis.
            % avg_trigger_interval and stim_end will be computed.
            % Average analysis will be called if the trigger times for
            % average (or session) are given.
           
            % Assign new times
            r.avg_trigger_times = new_times;           
            %
            numAvgTrigger = numel(r.avg_trigger_times);
            fprintf('Num of Avg triggers: %d.\n', numAvgTrigger);
            
            if numAvgTrigger < 2 
                % no avg analysis
                disp('Single trial response. No avg analysis.');
            else
                r.avg_trigger_interval = r.avg_trigger_times(2) - r.avg_trigger_times(1);
                
                % Possible options for duration for average analysis
                disp('Set duration for the average analysis.');
                if ~isempty(r.avg_duration)
                    fprintf('0. Current set duration (%.1f sec).\n', r.avg_duration);
                    n_default = 0;
                else
                    n_default = 1;
                end
                fprintf('1. interval between avg trigger times (%.1f sec).\n', r.avg_trigger_interval);
                %fprintf('2. ')
                fprintf('99. Get new duration from keyboard.')
                n = input(sprintf('Enter option no. [%d]\n or provide a specific time duration in secs: ', n_default));
                if isempty(n)
                    n = n_default;
                end
                switch n
                    case 0
                        % do nothing
                    case 1
                        r.avg_duration = r.avg_trigger_interval;
                    case 2
                    otherwise
                        r.avg_duration = n;    
                end

                if r.f_times(end) < (r.avg_trigger_times(end) + r.avg_duration)
                    r.stim_end = r.f_times(end);
                    numRepeat = numAvgTrigger - 1;
                else
                    r.stim_end = r.avg_trigger_times(end) + r.avg_duration;
                    numRepeat = numAvgTrigger;
                end
                fprintf('Num of full repeats: %d.\n', numRepeat);
                
                % Let's do avg analysis
                r.avg_FLAG = true;
                % (avg_trigger_times, avg_trigger_interval) --> avg analysis.
                r.average_analysis;                
            end
            
           
          
                      
        end
        
        function set.avg_FIRST_EXCLUDE(r, value)
            r.avg_FIRST_EXCLUDE = value;
            r.average_analysis;
        end
          
        function set.stim_trigger_times(obj, value)
            obj.stim_trigger_times = value;
            obj.stim_times = value; % old name
        end
        
        function set.roi_filtered_norm(obj, value)
            obj.roi_filtered_norm = value;
            obj.roi_normalized = value;
        end
        
        function set.avg_times(obj, value)
            obj.avg_times = value;
            obj.s_times = value; % old name
        end
        
        function set.avg_trigger_interval(obj, value)
            obj.avg_trigger_interval = value;
            obj.stim_trigger_interval = value; % no more use due to irregular trigger interval
            obj.stim_duration = value; % old name for stim_trigger_interval
        end
        
%         function set.stim_trigger_interval(obj, value)
%             obj.stim_trigger_interval = value;           
%         end
%         
        function value = get.stim_whitenoise(obj)
            value = obj.stim_movie;
        end
    end
    
end % classdef

function aa = vec(a)
    aa = a(:);
end

function [J, MinMax] = myadjust(I, c)
% Contrast-enhanced mapping to [0 1] of matrix I
% Input: contrast value (%)
    I = mat2gray(I); % Normalize to [0 1]. 
    Tol = [c*0.01 1-c*0.01];
    MinMax = stretchlim(I,Tol);
    J = imadjust(I, MinMax);
end

function J = myshow(I, c)
%imshow with contrast value (%)
    if nargin < 2
        c = 0.2;
    end
    J = myadjust(I, c);
    imshow(J);
end

function [bw_selected, bw_array] = cc_to_bwmask(cc, id_selected)
% convert cc to bwmask array and totla bw for selected IDs.

    if nargin < 2
        id_selected = 1:cc.NumObjects;
    end

    bw_array = false([cc.ImageSize, cc.NumObjects]);

    for i = 1:cc.NumObjects
        grain = false(cc.ImageSize);
        grain(cc.PixelIdxList{i}) = true;
        bw_array(:,:,i) = grain;
    end
    % Total bw for selected IDs
    bw_selected = max( bw_array(:,:,id_selected), [], 3);
end

function bw = lowerpixels(I, c) % 2D matrix, percentage. Output is logical array.
    if nargin < 2
        c = 0.5;
    end
    [J, ~] = myadjust(I, c); % J is the clipped-image by the given contrast (%).
    bw = (J ==0);            % Pixel value is 0 if value was in the lowest value group clipped by the contrast. 
end


