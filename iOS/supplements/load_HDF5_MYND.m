% example for loading data files recorded with the MYND app
% 05/04/2020 (c) Matthias Hohmann (mhohmann@tue.mpg.de)

function [data, meta, protocol] = load_HDF5_MYND(file_path)

    disp('Loading MYND HDF5 file...');    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Import MYND HDF5 file  %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Create attribute container for run  %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%    
    meta = containers.Map;
    
    %%%%%%%%%%%%%%%%%%%%%%%%
    % Load Version specific things %
    %%%%%%%%%%%%%%%%%%%%%%%%  
    
    %% Other attributes
    version = h5readatt(file_path, '/Recording', 'Version');
    if version >= 2 
       atts = {'Session', 'Run', 'TotalTrialsCompleted', 'SessionTrialsCompleted', 'recordingTime', 'recordingStartTime','recordingEndTime', 'sessionStartTime', 'scenario'};
       for i = 1:length(atts)
         try
            meta(atts{i}) = h5readatt(file_path, '/Recording', atts{i});
         catch
            disp(['Attribute ' atts{i} 'could not be loaded']);
         end
       end
    end
    
    %% Fitting time
    try
        meta('FittingTime') = str2double(cell2mat(h5readatt(file_path, '/Recording', 'fittingTime')));
    catch
        disp('Fitting Time value was corrupted, setting to 0');
        meta('FittingTime') = 0;
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%
    % Store data in object %
    %%%%%%%%%%%%%%%%%%%%%%%%
    meta('SamplingRate') = str2double(cell2mat(h5readatt(file_path, '/Recording', 'samplingRate')));
    meta('ChannelNames') = h5read(file_path, '/Recording/ChannelNames');
    
    data = h5read(file_path, '/Recording/Data');
    
    % add marker channel
    data(end+1,:) = h5read(file_path, '/Recording/Marker');
    
    % add timestamp
    data(end+1,:) = h5read(file_path, '/Recording/TimeStamp');
    
    % adjust timestamp baseline if needed
    % data(end,2:end) = data(end,2:end) - min(data(end,2:end));
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Store protocol in object %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%
   
    protocol.paradigm = string(cell2mat(h5readatt(file_path, '/Paradigm', 'Paradigm')));
    protocol.nrconditions = h5readatt(file_path, '/Paradigm', 'ConditionCount');
    protocol.conditions = string(h5read(file_path, '/Paradigm/ConditionLabels'));
    protocol.basemarkers = h5read(file_path, '/Paradigm/BaseMarkers');
    protocol.condmarkers = h5read(file_path, '/Paradigm/ConditionMarkers');
    protocol.basetime = h5readatt(file_path, '/Paradigm', 'BaseTime');
    protocol.trialtime = h5readatt(file_path, '/Paradigm', 'TrialTime');
end