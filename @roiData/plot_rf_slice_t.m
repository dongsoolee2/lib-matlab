function plot_rf_slice_t(r, rf, s)
    [num_x, num_t] = size(rf);
    plot(s.slice_t, 'LineWidth', 1.5);
        ax = gca;
            time_tick_label = 1:2:(num_t*r.ifi*10); % [ 100 ms]
            time_tick_locs = time_tick_label * 0.1 / r.ifi;
            S = sprintf('%.0f*', time_tick_locs*r.ifi*10 ); time_label = regexp(S, '*', 'split'); % C is cell array.
        ax.XTick = time_tick_locs;
        ax.XTickLabel = {time_label{1:end-1}};
        ax.YTick = 0;
        %ax.YTickLabel = [];
        ax.FontSize = 12;
        xlabel('[x100 ms]');
        ylabel('[a.u.]');
        grid on
        ylim([s.min s.max]);
end
