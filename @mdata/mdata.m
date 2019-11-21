classdef mdata < matlab.mixin.Copyable
    
    properties
        header
        exp_id
        
        count % total count over integration time
        period % int time
        t      % timestamp
        
        % Count (rate) of interest
        cri
        cri_onset_ps
        cri_until_ps
        cri_param
        
        % DTOF
        dtof_param
        dtof_mean
        dtof_raw % histogram x timestamp (or exp conditions) x channels
        dtof
        
        tau
    end
    
    methods
        function m = mdata(filename)
            
            if nargin > 0
                    
                m.import_Juliet_H5(filename);
                
            end
            
        end
        
        
    end
            
end
