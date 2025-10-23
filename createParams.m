%% Create Parameters
%   Editor:    Daniel Elbich
%   Created   :   3/14/19
%
%   Creates parameters .mat file for use with MVPA scripts
%
% 
%   Updated:   5/22/20

%   Major Updates:
%   -Removed ROI processing. Only directories are handled now
%   -fMRIPrep output data is not integrated into the pipeline
%   -Reorganized script to handle variable preprocessing.
%
%   Updated:   9/19/19
%
%   Major updates:
%   -Added flag for regressing reaction time (RT) from betas prior to
%   classification
%   -Added flag and variables for bootstrap MVPA classification
%   -Added ERS functionality
%+
%
%   Minor updates:
%   -Cleaned up code to get subject list/directories
%   -Cleaned up code saving mat files with ROI names to preven overwriting
%   between ROI & Searchlight analyses
%
%
%   Updated:   4/22/19
%
%   Major updates:
%   -Added section to create separate params file for use with Specify
%   Model script. This will be deleted during creation of final param mat
%   file.
%   -Rescling now completed through AFNI. Must loaded/added to system PATH
%
%   Minor updates:
%   -Searches common folder for ROI masks instead of project folder
%   -List dialog to select 1 or more regions for reslicing
%   -User input to select searchlight/no searchlight anlaysis
%   -User input to select conditions of interest
%   -Saves subjects, rois, and conds variables to var directory in project
%   folder


%% Set Pipeline Parameters

% --- USER SETTINGS --- %
% DEB: Define the list of subjects to process.
% The script will look for folders with these exact names (e.g., 'sub-101', 'sub-201')
subject_numbers = [101 102 104:108 110:128 130 133:143 146 148 151 152 154:157 159 160 162:166 170 171 ...
    402:426 428:435 437:440 442:448 450:458 460 ...
    202:203 206:210 215:218 221:223 226:230 233 236 237 239 243:245 248:257 259 261 266 ...
    501:510 512 513 516 518:534 536:542 544 545 547:562];
subjects = cellfun(@(x) sprintf('sub-%d', x), num2cell(subject_numbers), 'UniformOutput', false);


%  Set Path Variables

% Parent/Project Path - directory containing project data and analyses
directory.Project = '/home/acclab/Desktop/axc';

% DEB: Path to preprocessed functional data, as user specified using fmriprep
rawData.funcDir = [directory.Project filesep 'derivatives' filesep 'fmriprep'];

% Directory of the behavioral data file.
% DEB: User has behavioral data in each subject's 'beh' folder.
% This will be handled in specifyModel.m.
rawData.behavDir = 'beh';

% Extension of the behavioral file to help search
rawData.behavFile = '.tsv';

% Functional Data Preprocessing Program
preprocPipeline = 'fmriprep';

%% Task and Data Information

% Task Name
taskInfo.Name = 'retrieval';

% Conditions of Interest
taskInfo.Conditions = {'cr_new', 'hit_same', 'fa_sim', 'cr_sim'};

% Accuracy flag
taskInfo.accuracyFlag = 'No';

% Default number of runs (can be overridden in subject_config.m)
taskInfo.Runs = 4;

% Number of trials per run
taskInfo.Trials = 89;


%% Set Project Specific Variables

% Please specify:
% -The units used (i.e., 'scans' or 'secs')
% -The TR or repition time
Model.units = 'secs';
Model.TR    = 0.8;
    
    % Please specify if a mask is used during model estimation
    Mask.on   = 0; %Default - no mask used
    Mask.dir  = '/path/to/mask/directory';
    Mask.name = 'name_of_mask.nii';
    
    switch preprocPipeline
        case 'spm12'
            Func.dir         = [directory.Project filesep rawData.funcDir];
            Func.wildcard    = '^ar.*\.nii'; % File
            taskInfo.Slices = inputdlg('How many slices [# of slices in volume]?',...
                'Number of Slices',[1 35],{'50'});
            taskInfo.Slices = str2double(taskInfo.Slices{:});
            
        case 'fmriprep'
            Func.dir         = [directory.Project filesep rawData.funcDir];
            Func.wildcard    = ['^*' taskInfo.Name '_run-']; % File
            Func.prefix      = 'w';
            
    end
    
%% Project Paths

% General path setup
directory.Analysis = [directory.Project filesep 'multivariate'];
directory.Model = [directory.Analysis filesep 'models' filesep ...
    'SingleTrialModel' taskInfo.Name];
setenv('analysisPath',directory.Model);
!mkdir -p $analysisPath

analysisList = {'RSA'};
classType = analysisList{1};

% DEB: Select analysis type. Options: 'ROI' or 'Searchlight'
analysisType = 'ROI';

% Account for RT/regress out.
regressRT.flag = 'No';

%% Classification Flags

% Bootstrapping Setup
bootstrap.flag  = 'No';
if strcmpi(bootstrap.flag,'Yes')==1
    bootstrap.numRuns     = taskInfo.Runs;
    bootstrap.numTrials   = taskInfo.Trials;
    bootstrap.perm        = 1000;
    
    bootstrap.trialsPerRun = randperm(length...
        (1:bootstrap.numTrials));
    
    for i=1:bootstrap.numRuns
        bootstrap.structNames{i} = ['perm' num2str(i)];
    end
end
switch classType
    % MVPA Flags
    case 'MVPA'
        % Compute MVPA with entire run to train/test or individual
        % trials to train/test
        trialAnalysis = 'Run';
        leaveRuns = NaN;
        if strcmpi(analysisType, 'Searchlight')==1
            searchlight.Metric = 'radius';
            searchlight.Size = 50;
        end

    % RSA Flags
    case 'RSA'
        % Compute RSA with mean activation pattern (average all trials)
        % or individual trial pattern (all trials are separate)
        trialAnalysis = 'Individual';
        leaveRuns = NaN;
        if strcmpi(analysisType, 'Searchlight')==1
            searchlight.Metric = 'radius';
            searchlight.Size = 50;
        end
end

% DEB: The subject list is now defined at the top of the script.
% This section is no longer needed.
%
% %% Create Subject List
%
% try
%     % List subject directory
%     subjDir=dir(rawData.funcDir);
%
%     % Remove any files in directory
%     for i=1:length(subjDir)
%         if subjDir(i).isdir==0
%             fileFlag(i) = 0;
%         else
%             fileFlag(i) = 1;
%         end
%     end
%     subjDir = subjDir(logical(fileFlag));
%
%     % Remove non-subject directories
%     % change subject tags according to project**
%     for i=1:length(subjDir)
%         subFlag(i) = ~isempty(strfind(subjDir(i).name, 'sub-')); %change here to reflect you subject naming
%     end
%     subjDir = subjDir(subFlag);
%
%     % Search directory to get list of subjects
%     for i=1:length(subjDir)
%         subjects{i,1}=subjDir(i).name;
%     end
%
%     clear subjCount i subjDir;
% catch
%     warning('Unable to create subject list. Set to debug mode.');
% end

%% Assign Conditions
% DEB: Conditions are already set above.
subconditionFlag = 'FALSE';

%% Set filename for output

try
    % Set filename for parameter .mat file
    for i=1:length(taskInfo.Conditions)
        if i==1
            conds=taskInfo.Conditions{i};
        else
            conds=[conds '-' taskInfo.Conditions{i}];
        end
        
    end
    switch analysisType
        case 'Searchlight'
            filename=strcat(directory.Analysis,'/params_',preprocPipeline,...
                '_',taskInfo.Name,'_',classType,'_',analysisType,'_Conds_',...
                conds,'_subConds_',subconditionFlag,'_Bootstrap_',...
                bootstrap.flag,'_Searchlight',searchlight.Metric,'_',...
                num2str(searchlight.Size),'.mat');
        otherwise
            filename=strcat(directory.Analysis,'/params_',preprocPipeline,...
                '_',taskInfo.Name,'_',classType,'_',analysisType,'_Conds_',...
                conds,'_subConds_',subconditionFlag,'_Bootstrap_',...
                bootstrap.flag,'_Searchlight_No.mat');
    end
    
catch
    warning('Unable to set params filename. Set to debug mode.');
end

%% Save Params File
switch analysisType
    case 'Searchlight'
        save(filename,'directory','rawData','preprocPipeline',...
            'taskInfo','Model','Mask', 'Func','classType',...
            'subjects','analysisType','regressRT','searchlight',...
            'bootstrap','trialAnalysis','leaveRuns');
    otherwise
        save(filename,'directory','rawData','preprocPipeline',...
            'taskInfo','Model','Mask','Func','classType',...
            'subjects','analysisType','regressRT',...
            'bootstrap'); %'trialAnalysis' ,'leaveRuns'
end

%% Create PBS Script for Command Line Processing

% Identify shell script
cmd=which('multi-FRAME/modeling/createPBSScript.sh');
setenv('cmd',cmd);

% Break filename into parts
[filepath,name]=fileparts(filename);

% Set Variables
setenv('fileName',name);
setenv('filePath',filepath);
setenv('project',directory.Project);

% Create PBS script
!sh $cmd --paramsFile $fileName --paramsDir $filePath --projectDir $project

%% Cleanup

disp('All finished!!');
