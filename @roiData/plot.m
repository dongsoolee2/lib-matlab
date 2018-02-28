function plot(r)
% Method of class 'roiData'
% Create new figure with interactive keyboard navigation over roi#

    hfig = figure('Position', [100 230 1300 840]);
    axes('Position', [0  0  1  0.9524], 'Visible', 'off');
    
    cc = r.roi_cc;
    ev = r.stim_times;
    interval = r.stim_duration;
    % setting for figure
%     hfig.Color = 'none';
%     hfig.PaperPositionMode = 'auto';
%     hfig.InvertHardcopy = 'off';
    % callback
    set(hfig, 'KeyPressFcn', @keypress)
    
    % roi # and max #
    i_roi = 1;
    imax = r.numRoi;
    S = sprintf('ROI %d  *', 1:imax); C = regexp(S, '*', 'split'); % C is cell array.
    
    % roi rgb image
    labeled = labelmatrix(cc);
    RGB_label = label2rgb(labeled, @parula, 'k', 'shuffle');
    
    %
    n_col_subplot = 3;
    n_row_subplot = 3;
    
    function redraw()
        mask = false(cc.ImageSize);
        
        % 1. whole trace
        subplot(n_row_subplot, n_col_subplot, [1, n_col_subplot]);
            plot_raw(r, i_roi);
%                 ax = findobj(gca, 'Type', 'Line');
%                 ax.LineWidth = 0.8;            
        subplot(n_row_subplot, n_col_subplot, [n_col_subplot+1, 2*n_col_subplot]);
            plot_trace(r, i_roi);
%                 ax = findobj(gca, 'Type', 'Line');
%                 ax.LineWidth = 0.8;            
            
        subplot(n_row_subplot, n_col_subplot, 2*n_col_subplot+1);
            %axes('Position', [0  0  1  1], 'Visible', 'off');
            mask(cc.PixelIdxList{i_roi}) = true;
            h = imshow(RGB_label);
            set(h, 'AlphaData', 0.9*mask+0.1);
            
            ax = gca;
            str1 = sprintf('%d/%d ROI', i_roi, imax);
            text(ax.XLim(end), ax.YLim(1), str1, 'FontSize', 12, 'Color', 'k', ...
                'VerticalAlignment', 'bottom', 'HorizontalAlignment','right');
            
        % 3. roi avg over multiple repeats
        subplot(n_row_subplot, n_col_subplot, 2*n_col_subplot+2);
            ax = plot_avg(r, i_roi);
            
        % 4. roi avg over multiple repeats (filtered)
        subplot(n_row_subplot, n_col_subplot, 2*n_col_subplot+3);
            ax = plot_avg_fil(r, i_roi);

    end

    redraw();
    
    function keypress(~, evnt)
        
        switch lower(evnt.Key)
            case 'rightarrow'
                i_roi = min(i_roi + 1, imax); 
            case 'leftarrow'
                i_roi = max(1, i_roi - 1);
                
            otherwise
                return;
        end
        redraw();
    end

end