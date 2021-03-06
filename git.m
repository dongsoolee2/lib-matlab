function varargout = git(varargin)
% GIT Execute a git command.
%
% GIT <ARGS>, when executed in command style, executes the git command and
% displays the git outputs at the MATLAB console.
%
% STATUS = GIT(ARG1, ARG2,...), when executed in functional style, executes
% the git command and returns the output status STATUS.
%
% [STATUS, CMDOUT] = GIT(ARG1, ARG2,...), when executed in functional
% style, executes the git command and returns the output status STATUS and
% the git output CMDOUT.
%
% https://stackoverflow.com/questions/42271061/matlab-git-by-command-window

% Check output arguments.
nargoutchk(0,2)

% Specify the location of the git executable.
%gitexepath = 'C:\path\to\GIT-2.7.0\bin\git.exe';

str = computer;
switch str
    case 'MACI64'
        gitexepath = ['"/usr/bin/git"'];
    case 'PCWIN64'
        gitexepath = ['"C:\Program Files\Git\cmd\git.exe"'];
    otherwise
        error('OS should be Mac OS X or PCWIN64');
end
% gitdir = 'C:\Program Files\Git\cmd\';
% gitexepath = [gitdir,'gits.exe'];

% Construct the git command.
cmdstr = strjoin([gitexepath, varargin]);

% Execute the git command.
[status, cmdout] = system(cmdstr);

switch nargout
    case 0
        disp(cmdout)
    case 1
        varargout{1} = status;
    case 2
        varargout{1} = status;
        varargout{2} = cmdout;
end