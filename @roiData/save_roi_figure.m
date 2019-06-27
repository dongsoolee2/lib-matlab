function save_roi_figure(r)
% plot and save roi figure.
% r.image may be updated by i_th snap instead of mean image.

roi_fig_name = [r.ex_name, '_roi'];

if isfield(r.roi_cc, 'i_image') % save i-th image among
    r.image = r.snaps(:,:,r.roi_cc.i_image);
    roi_fig_name = [roi_fig_name, '_snap_',num2str(r.roi_cc.i_image)];
else
    
% save
utils.figure; 
r.plot_roi; 

print(roi_fig_name, '-dpng', '-r300'); %high res
                

end