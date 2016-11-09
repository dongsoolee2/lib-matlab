function ev_idx = pd_event_display(pd, min_ev_interval_secs, th_event, srate)

if nargin < 4
    srate = 10000;
end
if nargin < 3
    th_event = 0.7;
end
if nargin < 2
    min_ev_interval_secs = 0.5;
end

num = length(pd);
pdts = (1:num)/srate;

%figure('position', [680 620 1250 500]);
figure;
%
ax1 = subplot(3, 1, 1);
plot(pdts', pd); hold on;
xlim([0 50]);
xlabel(ax1, '[secs]');
%
ax2 = subplot(3, 1, 2);
plot(pdts', pd); hold on; 
xlim([pdts(end)-300, pdts(end)]);
xlabel(ax2, '[secs]');

% event
ev_idx = th_crossing(pd, th_event, min_ev_interval_secs*srate);
plot(ax1, pdts(ev_idx), pd(ev_idx), 'bo');
plot(ax2, pdts(ev_idx), pd(ev_idx), 'bo');

% event is regular?
inter_event_interval = ev_idx(2:end) - ev_idx(1:end-1);
ax3 = subplot(3, 1, 3);
plot(inter_event_interval/srate, '-o');
xlabel(ax3, 'event id');
ylabel(ax3, 'Interevent duration [s]');
ylim(ax3, [0 inf]);

end