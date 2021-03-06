function plot_counts(r, I)
% Create new figure with interactive keyboard navigation over roi#

    if nargin < 2
        if ~isempty(r.roi_good)
            I = r.roi_good;
        else
            I = 1:r.numRoi;
        end
    end
    i_roi = 1;
    imax = numel(I);

    hfig = figure('Position', [930 785 1250 500]);
    axes('Position', [0  0  1  0.9524], 'Visible', 'off');
    
    % callback
    set(hfig, 'KeyPressFcn', @keypress)
    
    % roi # and max # 
    S = sprintf('ROI %d  *', 1:imax); C = regexp(S, '*', 'split'); % C is cell array.
    
    % subplot info
    n_col = 3;
    n_row = 2;
    
    function redraw()
        k = I(i_roi); % roi index
        fprintf('ROI id: %d\n', k);
        %mask = false(cc.ImageSize);
        % ex info
        ex_info = sprintf('smooth size %d (~%.0f ms)', r.smoothing_size, r.ifi*r.smoothing_size*1000);
        ex_info = [];
        
        % plot name   
        str_name = sprintf(' delay %.1f ns', (k-1)*0.5);
        if k == 5
            str_name = ' Null exp';
        end
        
        % 1. whole trace
        subplot(n_row, n_col, [1, n_col-1]);
            plot_trace_raw(r, k);
            ylabel('Photon Counts');
            xlabel('sec')
            ax = gca;
            ax.YAxis.Exponent = 0;
            maxC = max(ax.YAxis.TickValues);
            if maxC > 1e6
                labels = sprintf('%.2f M*', ax.YAxis.TickValues*1e-6);
            elseif maxC > 1e5
                labels = sprintf('%.0f K*', ax.YAxis.TickValues*1e-3);
            else
                labels = sprintf('%.1f K*', ax.YAxis.TickValues*1e-3);
            end
            labels = regexp(labels, '*', 'split');
            labels = labels(1:end-1);
            ax.YAxis.TickLabels = labels;
            
            
        subplot(n_row, n_col, n_col);
            cla
            axis auto
            plot_avg(r, k, 'traceType', 'smoothed', 'Name', str_name, 'Std', true, 'Corr', false);  
            %plot_avg(r, k, 'traceType', 'smoothed_norm_repeat', 'Name', str_name, 'Std', true, 'Corr', false);
                
                title('Avg response (smoothed)', 'FontSize', 16);                              
                ax = gca;
                ax.YAxis.Exponent = 0;
                if maxC > 1e6
                    labels = sprintf('%.2f M*', ax.YAxis.TickValues*1e-6);
                elseif maxC > 1e5
                    labels = sprintf('%.0f K*', ax.YAxis.TickValues*1e-3);
                else
                    labels = sprintf('%.1f K*', ax.YAxis.TickValues*1e-3);
                end
                labels = regexp(labels, '*', 'split');
                labels = labels(1:end-1);
                ax.YAxis.TickLabels = labels;
                % Correlation between traces                    
                str = sprintf('%.2f', r.p_corr.smoothed(k));
                text(ax.XLim(end), ax.YLim(2), ['{\it r} = ',str], 'FontSize', 15, 'Color', 'k', ...
                            'VerticalAlignment', 'top', 'HorizontalAlignment','right');
                ylabel('Photon Counts');
                xlabel('sec')

            
        subplot(n_row, n_col, [n_col+1, 2*n_col-1]);
            plot_trace_norm(r, k);
            ylabel('{\it \Delta}C/C_{trend} [%]');
            xlabel('sec')
            
        subplot(n_row, n_col, 2*n_col);
            cla;
            axis auto
            plot_avg(r, k, 'traceType', 'smoothed_detrend_norm', 'Name', str_name, 'Std', true, 'Corr', false);
            title('Avg response (normalized)', 'FontSize', 16);
            ylabel('{\it \Delta}C/C_{trend} [%]');
            xlabel('sec')
            ax =gca;
            % Correlation between traces                    
            str = sprintf('%.2f', r.p_corr.smoothed_detrend_norm(k));
            text(ax.XLim(end), ax.YLim(2), ['{\it r} = ',str], 'FontSize', 15, 'Color', 'k', ...
                        'VerticalAlignment', 'top', 'HorizontalAlignment','right');
    end

    redraw();
    
    function keypress(~, evnt)
        a = lower(evnt.Key);
        switch a
            case 'rightarrow'
                i_roi = i_roi + 1;
                if i_roi > imax
                    i_roi = 1;
                end
            case 'leftarrow'
                i_roi = i_roi - 1;
                if i_roi < 1
                    i_roi = imax;
                end

            otherwise
%                 n = str2double(a);
%                 if (n>=0) & (n<10)
%                     k = I(i_roi);
%                     r.c(k) = n;
%                     %r.c{n} = [k, r.c{n}];
%                     r.plot_cluster(4, n);
%                     fprintf('New ROI %d is added in cluster %d,\n', k, n);
%                     % increase roi index automatically
%                     i_roi = i_roi + 1;
%                     if i_roi > imax
%                         i_roi = 1;
%                     end 
%                 end
        end
        figure(hfig);
        redraw();
    end

end