function ids = plot_repeat(r, I, varargin)
% PLOT version 'repeat'.
% Limited number of plots per figure. Keyboard navigation for next set of
% ROIs.
%
% output:
%           'ids' - array of ROI index (filtered by correlation)
%
% varargin:
%           'PlotType' : For indivial trace. 'tiled' (default) or
%           'overlaid' (Black mean + overlaid all traces except 1st one)
    
    p=ParseInput(varargin{:});
    PlotType = p.Results.PlotType;
    
    if nargin < 2
        p = 0.2;
        I = 1:r.numRoi;    
        I = I(r.p_corr.smoothed_norm > p);
        fprintf('[plot_repeat] %d ROIs are seleted with a condition of p > %.2f.\n', numel(I), p);
    end
    if length(I) == 1 && I < 1 % I as p upper limit
        p = I;
        I = 1:r.numRoi;    
        I = I(r.p_corr.smoothed_norm > p);
        fprintf('[plot_repeat] %d ROIs are seleted with a condition of p > %.2f.\n', numel(I), p);
    end
    ids = I;
    n_ROI = numel(I);
    S = sprintf('ROI %d  *', I); C = regexp(S, '*', 'split'); % C is cell array.
    
    % cluster id & initialize projection vector
%     i_c = 1; % id in sorted cluster array
%     p = zeros(size(r.c_mean, 2));
%     i_sorted = zeros(1, 100);
%     % Color setting for clusters;
%     c_list = unique(r.c(r.c~=0)); 
%     c_list_num = numel(c_list);
%     color = jet(c_list_num); 
    
    % Figure 
    hfig = figure('Position', [10 300 800 900]);
    %axes('Position', [0  0  1  0.9524], 'Visible', 'off');
    
    % callback
    set(hfig, 'KeyPressFcn', @keypress)
    % roi rgb image
    labeled = labelmatrix(r.roi_cc);
    RGB_label = label2rgb(labeled, @parula, 'k', 'shuffle');
    
    % subplot info
    n_col = 4;
    n_row = 2;
    n_plots_per_fig = n_col * n_row;
    n_figs = ceil(n_ROI/n_plots_per_fig);
    i_fig = 1;
    
     % axes dim for single ROI (cell)
        m = 0.1; % margin
        h_ax = (1-m)/n_row;
        w_ax = (1-m)/n_col;
        h_ax_mean   = 1/n_row * (1/4) * 0.9;
        h_ax_repeat = 1/n_row * (3/4) * 0.9;
        if contains(PlotType, 'overlaid')
            n_row = 5;
            h_ax = (1-m)/n_row;
            h_ax_mean   = 1/n_row * 0.9;
            h_ax_repeat = 0;
            n_plots_per_fig = n_col * n_row;
            n_figs = ceil(n_ROI/n_plots_per_fig);
        end 
        
    [I_plot, J_plot] = ind2sub([n_row, n_col], 1:n_plots_per_fig);
        
    function redraw()   
        % delete all objects
        delete(hfig.Children);
               
        for i = 1:n_plots_per_fig % loop over position id
            
            i_cell = (i_fig - 1) * n_plots_per_fig + i;
            if i_cell > n_ROI
                break;
            end
            k = I(i_cell); % real ROI index
            
            % x y position given cell id
            x_ax = m/2. + (J_plot(i)-1) * w_ax;
            y_ax = m/2. + (I_plot(i)-1) * h_ax;
             
            % All traces (smoothed_norm)
            y = r.roi_smoothed_norm(:, k);
                [y_aligned, ~] = align_rows_to_events(y, r.f_times_norm, r.avg_trigger_times, r.avg_trigger_interval);
                y_aligned = reshape(y_aligned, size(y_aligned, 1), []);
%             
%             % All traces (smoothed)
%             y = r.roi_smoothed(:, k);
%                 [y_aligned, ~] = align_rows_to_events(y, r.f_times, r.avg_trigger_times, r.avg_trigger_interval);
%                 y_aligned = reshape(y_aligned, size(y_aligned, 1), []);
%             
                % n_cycle and phase shift (row vectors)
                y_aligned = circshift(y_aligned, round( r.s_phase * size(y_aligned, 1)), 1); % last param is DIM.
                y_aligned = repmat(y_aligned, [r.n_cycle, 1]);               

            n_trace = size(y_aligned, 2);
            str = sprintf('corr = %.2f ', r.p_corr.smoothed(k));
                    
            % 2. Draw Mean (& std) trace
            axes('Position', [x_ax,  y_ax+h_ax-h_ax_mean  0.8*w_ax  0.9*h_ax_mean], 'Visible', 'off');
                
                if contains(PlotType, 'overlaid')
                        
                    % individual traces first (ignore 1st trace?!)
                    disp('[Plot_repeat] 1st trace was ignored.');
                    plot(r.a_times, y_aligned(:,10:19), 'LineWidth', 1.2); 
                    xlim([ max(r.t_range(1), r.a_times(1)), min(r.t_range(end),r.a_times(end)) ]);
                    hold on
                    
                    r.plot_avg(k, 'traceType', 'normalized', 'LineWidth', 3, 'Color', 'k', 'Label', false);
                    %title('Mean response');
                    hold off;
                    
                    ax = gca;
                    % Print P-correlation value
                    text(ax.XLim(end), ax.YLim(1), str, 'FontSize', 14, 'Color', 'k', ...
                                'VerticalAlignment', 'bottom', 'HorizontalAlignment','right');

                else
                    % Mean
                    r.plot_avg(k, 'traceType', 'normalized'); 
                    title('Mean response');
                    
                    h_ax_one_trace = 0.85*(h_ax_repeat-m/4.)/n_trace;

                    for ii = 1:n_trace
                        axes('Position', [x_ax,  y_ax + m/2. + (n_trace-ii)*h_ax_one_trace,  0.8*w_ax,  h_ax_one_trace], 'Visible', 'off');
                        plot(r.a_times, y_aligned(:,ii), 'LineWidth', 1.2);
                        xlim([ max(r.t_range(1),r.a_times(1)), min(r.t_range(end),r.a_times(end)) ]);
                        axis tight
                        axis off
                    end
                    ax = gca;
                    % Print P-correlation value
                    text(ax.XLim(end), ax.YLim(1), str, 'FontSize', 14, 'Color', 'k', ...
                                'VerticalAlignment', 'top', 'HorizontalAlignment','right');                    
                end
                
        end
    end
    
    redraw();
    
    function keypress(~, evnt)
        a = lower(evnt.Key);        
        %fprintf('key event is: %s\n', evnt.Key);
        switch a
            case 'rightarrow'
                i_fig = i_fig + 1;
                if i_fig > n_figs
                    i_fig = n_figs;
                end
                
            case 'leftarrow'
                i_fig = i_fig - 1;
                if i_fig < 1
                    i_fig = 1;
                end
       
            otherwise
                return;
        end
        figure(hfig);
        redraw();
    end

end

function aa = vec(a)
aa = a(:);
end

function p =  ParseInput(varargin)
    
    p  = inputParser;   % Create an instance of the inputParser class.
    
    p.addParameter('PlotType', 'tiled', @(x) strcmp(x,'tiled') || ...
        strcmp(x,'overlaid'));
      
    % Call the parse method of the object to read and validate each argument in the schema:
    p.parse(varargin{:});
    
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