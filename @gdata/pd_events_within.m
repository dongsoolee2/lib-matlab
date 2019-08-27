function triggers = pd_events_within(g, sess_id)
    % Returns pd trigger times under major (pd events1) trigger id.
    
    if nargin < 2
        sess_id = [];
    end
    
    n_session = numel(g.pd_events1);

    if isempty(sess_id)
        str = sprintf('There are %d session (pd events 1) triggers. \nWhich session do you want to retrieve for stim triggers? 1-%d [%d]\n', n_session, n_session, n_session); 
        sess_id = input(str);
        if isempty(sess_id); sess_id = n_session; end
    end

    % session on and off times.
    session_on  = g.pd_events1(sess_id);
    if sess_id < n_session
        session_off = g.pd_events1(sess_id+1);
        % 
    else
        session_off = g.f_times(end);
    end
    
    % triggers during the session
    triggers = g.pd_events2(g.pd_events2 >= session_on);
    %triggers = [session_on; triggers(:)]; % add the session_on time.
    triggers = triggers(triggers < session_off);
    
end