function push_git(varargin)

p = ParseInput(varargin{:});

gitexepath = ['C:\Program Files\Git\mingw64\bin\git.exe'];

commit_msg = input('Commit message? ', 's');

git('add -A');
git(['commit  -am "', commit_msg, '"']);
git push;

% eval('!git add -A')
% eval(['!git commit -am "', commit_msg, '"'])
% eval('!git push')

end

function p =  ParseInput(varargin)
    
    p  = inputParser;   % Create an instance of the inputParser class.
    
    addParamValue(p,'comment', 'my Macbook pro');
    
%     addParamValue(p,'barWidth', 100, @(x)x>=0);
%     addParamValue(p,'barSpeed', 1.4, @(x)x>=0);
%     addParamValue(p,'barColor', 'dark', @(x) strcmp(x,'dark') || ...
%         strcmp(x,'white'));
%      
    % Call the parse method of the object to read and validate each argument in the schema:
    p.parse(varargin{:});
    
end