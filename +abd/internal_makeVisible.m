function [] = internal_makeVisible(file, matlabVersion)
%   Restore visibility to a saved MATLAB figure file.
%
%   DO NOT RUN THIS FUNCTION.
%
%   Layup Analysis Tool 3.0.0 Copyright Louis Vallance 2024
%   Last modified 14-Feb-2024 15:05:03 UTC
%

%% - DO NOT EDIT BELOW LINE
%_______________________________________________________________________
%%
if (strcmpi(matlabVersion{1.0}, '2014b') == 1.0) || (matlabVersion{2.0} > 2014.0)
    top = load(file, '-mat', 'hgM_070000');
    top.hgM_070000.GraphicsObjects.Format3Data.CreateFcn = 'set(gcf, ''visible'', ''on'')';
    save(file, '-struct', 'top', '-append')
else
    f = load(file, '-mat');
    n = fieldnames(f);
    f.(n{1}).properties.Visible = 'on';
    save(file, '-struct', 'f')
end