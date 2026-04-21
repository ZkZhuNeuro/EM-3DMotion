%% Transfer files to box

ToDir = 'C:\Users\lwthompson\Box\Thompson2023_RosenbergLab\AllNeuralData\';

%% Transfer 2D files
for ifile = 1:size(files,1)
    fprintf('\nCopying 2D file %i/%i/\n',ifile,size(files,1));
    monkey = extractBetween(files.Paths(ifile),':\','\NeuroData');
    tinfo_path = fullfile(files.Paths(ifile),files.Names(ifile,1));
    sinfo_path = fullfile(files.Paths(ifile),files.Names(ifile,2));
    
    % Create subfolder for date
    folder_name = extractBetween(files.Paths(ifile),'NeuroData\','\');
    
    if ~isfolder(fullfile(ToDir,monkey,folder_name))
        new_folder = fullfile(ToDir,monkey,folder_name);
        mkdir(new_folder{:})
    end
    % Copy files
    fullToDir = fullfile(ToDir,monkey,folder_name,extractAfter(tinfo_path,folder_name));
    copyfile(tinfo_path{:}, fullToDir{:});
    fullToDir = fullfile(ToDir,monkey,folder_name,extractAfter(sinfo_path,folder_name));
    copyfile(sinfo_path{:}, fullToDir{:});
end

%% Transfer 3D files
for ifile = 1:size(files_3D,1)
    fprintf('\nCopying 3D file %i/%i',ifile,size(files_3D,1));
    monkey = extractBetween(files_3D.Paths(ifile),':\','\NeuroData');
    tinfo_path = fullfile(files_3D.Paths(ifile),files_3D.Names(ifile,1));
    sinfo_path = fullfile(files_3D.Paths(ifile),files_3D.Names(ifile,2));
    
    % Create subfolder for date
    folder_name = extractBetween(files_3D.Paths(ifile),'NeuroData\','\');
    
    
    if ~isfolder(fullfile(ToDir,monkey,folder_name))
        new_folder = fullfile(ToDir,monkey,folder_name);
        mkdir(new_folder{:})
    end
    % Copy files
    fullToDir = fullfile(ToDir,monkey,folder_name,extractAfter(tinfo_path,folder_name));
    if isfile(fullToDir{:})
        continue
    end    
    copyfile(tinfo_path{:}, fullToDir{:});
    fullToDir = fullfile(ToDir,monkey,folder_name,extractAfter(sinfo_path,folder_name));
    copyfile(sinfo_path{:}, fullToDir{:});
end

%% Transfer RF files
for ifile = 1:size(AllMonkeyRFTable,1)
    fprintf('\nCopying RF file %i/%i',ifile,size(AllMonkeyRFTable,1));
    monkey = extractBetween(AllMonkeyRFTable.Paths(ifile),':\','\NeuroData');
    tinfo_path = fullfile(AllMonkeyRFTable.Paths(ifile),AllMonkeyRFTable.Names(ifile,1));
    unit_path = [tinfo_path{1}(1:length(tinfo_path{1})-8), '_RFData_Unit', num2str(AllMonkeyRFTable.Unit(ifile)), '.mat'];
    % Create subfolder for date
    folder_name = extractBetween(AllMonkeyRFTable.Paths(ifile),'NeuroData\','\');
    
%     if ~isfolder(fullfile(ToDir,monkey,folder_name))
%         new_folder = fullfile(ToDir,monkey,folder_name);
%         mkdir(new_folder{:})
%     end
    % Delete all sparse noise files
%     fullToDir = join([ToDir,monkey,'\',folder_name,'\*SparseNoise*'],'');
%     fullToDir = fullToDir{:};
%     delete(fullToDir);

    % Copy files
    fullToDir = fullfile(ToDir,monkey,folder_name,extractAfter(tinfo_path,folder_name));
    copyfile(tinfo_path{:}, fullToDir{:});
    [FILEPATH,NAME,EXT] = fileparts(unit_path);
    fullToDir = fullfile(ToDir,monkey,folder_name, [NAME, EXT]);
    copyfile(unit_path, fullToDir{:});
end

