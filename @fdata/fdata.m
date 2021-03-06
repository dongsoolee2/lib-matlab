classdef fdata < handle
% Imaging data class under same FOV (same roi cc). Array of gdata objects

    properties
        FOV_name    % e.g. loc1, loc2, ...
        ex_name     %
        g           % gdata cell array
        img_mean    % mean image of all imaging sessions
        numImaging  % # of imaging sessions under same FOV
        %
        cc          % Setting cc will trigger to compute roi data for all imaging sessions
        numRoi
        roi_channel % PMT ch for ROI. ch# will be automatically shared. 
        roi_rgb     % roi rgb snapshot
        %
        roi_selected 
    end
    % pipieline: ch select -> cc input -> roi data 
    
    methods
        % constructor
        function obj = fdata(ex_str, dirpath)
           if nargin > 0
               obj.FOV_name = get_ex_name(ex_str);
               % in case of no dirpath
               if nargin < 2; dirpath = pwd; end;
               
               % List of filenames
               [tif_filenames, h5_filenames] = tif_h5_filenames(dirpath, ex_str)
               
               % File numbers
               numTifFiles = numel(tif_filenames);
               numh5Files = numel(h5_filenames);
               
               % Construct 1 X N gdata
               g(1, numTifFiles) = gdata;
               obj.ex_name = cell(1, numTifFiles);
               
               obj.numImaging = numTifFiles;
               for i =1:numTifFiles
                    tif_filename = [dirpath,'/',tif_filenames{i}];
                    if i <=numh5Files
                        h5_filename = [dirpath,'/',h5_filenames{i}];
                    else
                        h5_filename = [];
                    end
                    %
                    g(i) = gdata(tif_filename, h5_filename);
                    % save the filenmae after FOV_name
                    loc = strfind(tif_filename, obj.FOV_name);
                    obj.ex_name{i} = get_ex_name(tif_filename(loc:end));
               end
               obj.g = g;
               
               % mean image (for available channels)
               obj.img_mean = cell(1, g(1).n_channels);
               for ch = obj.g(1).header.channelSave
                   [row, col] = size(obj.g(i).AI_mean{ch});
                   obj.img_mean{ch} = zeros(row, col);
                   for i = 1:obj.numImaging
                        obj.img_mean{ch} = obj.img_mean{ch} + obj.g(i).AI_mean{ch};                        
                   end
                   obj.img_mean{ch} = obj.img_mean{ch}/obj.numImaging;
               end
               
           end
        end
        
        function imvol(f)
            for ch = f.g(1).header.channelSave
                imvol(f.img_mean{ch});
            end
        end
        
        % Create roi data for all imaging sessions
        function set.cc(obj, cc)
            % ch select
            if ~isempty(obj.roi_channel)
                % do nothing
            elseif obj.g(1).header.n_channelSave == 1
                ch = obj.g(1).header.channelSave(1);
                disp(['Ch# ',num2str(ch),' is selected for roi analysis']);
                obj.roi_channel = ch;
            else    
                ch = input(['Imaging PMT channel # (Available: ', num2str(obj.g(1).header.channelSave),') ? ']);
                obj.roi_channel = ch;
            end
            
            % cc struct input to create roi data in gdata class
            for i=1:obj.numImaging
                obj.g(i).cc = cc;
            end
            obj.cc = cc;
            obj.numRoi = cc.NumObjects;
            obj.roi_rgb = label2rgb(labelmatrix(cc), @parula, 'k', 'shuffle');
            obj.roi_selected = 1:obj.numRoi;
        end
        
        % roi analysis channel number set function
        function set.roi_channel(obj, ch)
            for i=1:obj.numImaging
                obj.g(i).roi_channel = ch;
            end
            obj.roi_channel = ch;
        end
        
        % (g)Data concatenate
        function concatenate(f, s1, s2)
            % new gdata object id
            id = f.numImaging + 1;
            f.g(id) = gdata;
            
            % info update
            f.g(id).ex_name = [f.g(s1).ex_name, ' and ', f.g(s2).ex_name];
            f.g(id).tif_filename  = [f.g(s1).tif_filename, ' and ', f.g(s2).tif_filename];
            % condition compare & merge
            % ifi
            if f.g(s1).ifi ~= f.g(s2).ifi
                disp('[@fdata: concatenate imaging sessions] ifi (= logFramePeriod) is differnet for two sessions.'); 
            else
                f.g(id).ifi = f.g(s1).ifi;
            end
            f.g(id).header  = f.g(s1).header;
            f.g(id).header.headers = [f.g(s1).header, f.g(s2).header];
            f.g(id).AI_chSave = f.g(s1).AI_chSave;
            f.g(id).roi_channel = f.g(s1).roi_channel;
            
            % data
            for ch = f.g(s1).header.channelSave
                f.g(id).AI{ch} = cat(3, f.g(s1).AI{ch}, f.g(s2).AI{ch});
            end
            f.g(id).nframes = size( f.g(id).AI{ f.g(id).AI_chSave(1) }, 3);
            
            % stimulus
            disp('[@fdata: concatenate imaging sessions] merging stim triggers is under development.');
        end
        
        function imshowpair(obj, s1, s2)
        % Compare mean images between imaging sessions
        % s1, s2 is session id#
        % no input: compare between all sessions
                for ch = obj.g(1).header.channelSave
                    figure('Position', [100 150 737 774]);
                    hfig.Color = 'none';
                    hfig.PaperPositionMode = 'auto';
                    hfig.InvertHardcopy = 'off';
                    axes('Position', [0  0  1  0.9524], 'Visible', 'off');
                    
                    if nargin >1
                        %imshowpair(obj.g(s1).AI_mean{ch}, obj.g(s2).AI_mean{ch});
                        im1 = obj.g(s1).myshow(ch);
                        im2 = obj.g(s2).myshow(ch);
                        imshowpair(im1, im2);
                        title(['session pair: ', num2str(s1), ', ', num2str(s2)], 'FontSize', 18, 'Color', 'k');
                    else 
                        % loop for non-diagonal subscripts.
                        n = obj.numImaging;
                        m = ones(n) - eye(n);
                        ind_pairs = find(m(:));
                        n_subplots = length(ind_pairs)/2;
                        i_plot =1;
                        kk = 1;
                        while kk <= length(ind_pairs)
                            k = ind_pairs(kk);
                            [i, j] = ind2sub([n, n], k);
                            if i >= j 
                                % do nothing
                            else
                                if n_subplots > 1 && n_subplots < 4
                                    subplot(1, n_subplots, i_plot);
                                elseif n_subplots >= 4
                                    subplot(2, ceil(n_subplots/2.), i_plot);
                                end
                                imshowpair(obj.g(i).AI_mean{ch}, obj.g(j).AI_mean{ch});
                                title(['session pair: ', num2str(i), ', ', num2str(j)], 'FontSize', 18, 'Color', 'k');
                                i_plot = i_plot +1;
                            end
                            kk = kk+1;
                        end
                    end
                end  
        end

    end
    
    
end


function [tif_filenames, h5_filenames] = tif_h5_filenames(dirpath, str)
    str_condition = ['/*',str,'*'];
    %
    tif_filenames = getfilenames(dirpath, [str_condition,'.tif']);
     h5_filenames = getfilenames(dirpath, [str_condition,'.h5']);
    %
    if isempty(tif_filenames)
        error('There are no tif files');
    end
end

function str_ex_name = get_ex_name(tif_filename)
    s_filename = strrep(tif_filename, '_', '  ');    
    s_filename = strrep(s_filename, '00', '');
    loc_name = strfind(s_filename, '.');
    
    if isempty(loc_name)
        str_ex_name = s_filename;
    else
        str_ex_name = s_filename(1:(loc_name-1));
    end
end

function str = get_unique_name(filename)


end