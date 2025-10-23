function run_first_level_setup()
    % A unified script for the first level setup of the multi-FRAME pipeline.
    %
    % This script combines the functionality of createParams, preprocessData, and
    % specifyModel to provide a seamless and robust setup for the first-level
    % analysis. By unifying these steps, it avoids any MATLAB workspace issues
    % where variables might be cleared between script executions.
    %
    % Workflow:
    % 1. Sets all user-defined parameters.
    % 2. Extracts and reformats motion regressors from fMRIPrep output.
    % 3. Creates the multiple conditions .mat files for each subject and run.
    %
    % After running this script, you can proceed to run estimateModel.m.

    clear; clc;
    fprintf('--- Starting Unified First-Level Setup ---\n\n');

    %==========================================================================
    %% CREATE PARAMS
    %==========================================================================
    fprintf('1. Defining Parameters...\n');

    % --- USER SETTINGS --- %
    subject_numbers = [101 102 104:108 110:128 130 133:143 146 148 151 152 154:157 159 160 162:166 170 171 ...
        402:426 428:435 437:440 442:448 450:458 460 ...
        202:203 206:210 215:218 221:223 226:230 233 236 237 239 243:245 248:257 259 261 266 ...
        501:510 512 513 516 518:534 536:542 544 545 547:562];
    subjects = cellfun(@(x) sprintf('sub-%d', x), num2cell(subject_numbers), 'UniformOutput', false);

    directory.Project = '/home/acclab/Desktop/axc';
    rawData.funcDir = fullfile(directory.Project, 'derivatives', 'fmriprep');
    rawData.behavDir = 'beh';
    rawData.behavFile = '.tsv';
    preprocPipeline = 'fmriprep';
    taskInfo.Name = 'retrieval';
    taskInfo.Conditions = {'cr_new', 'hit_same', 'fa_sim', 'cr_sim'};
    taskInfo.accuracyFlag = 'No';
    taskInfo.Runs = 4; % Default, will be overridden by subject_config
    taskInfo.Trials = 89;
    Model.units = 'secs';
    Model.TR    = 0.8;
    Mask.on   = 0;
    Mask.dir  = '/path/to/mask/directory';
    Mask.name = 'name_of_mask.nii';
    Func.dir = rawData.funcDir;
    Func.wildcard = ['^*' taskInfo.Name '_run-'];
    Func.prefix = 'w';
    directory.Analysis = fullfile(directory.Project, 'multivariate');
    directory.Model = fullfile(directory.Analysis, 'models', ['SingleTrialModel' taskInfo.Name]);
    analysisType = 'ROI';
    regressRT.flag = 'No';

    fprintf('   ...parameters defined successfully.\n\n');

    %==========================================================================
    %% PREPROCESS DATA (Regressor Extraction)
    %==========================================================================
    fprintf('2. Extracting Motion Regressors...\n');

    dataDir = directory.Project; % Corrected from older version

    for i = 1:length(subjects)
        current_subject_id = subjects{i};

        tsvFileDir = fullfile(dataDir, 'derivatives', 'fmriprep', current_subject_id, 'func');
        tsvFiles = dir(fullfile(tsvFileDir, ['*' taskInfo.Name '*confound*.tsv']));

        outputDir = fullfile(directory.Model, current_subject_id);
        if ~exist(outputDir, 'dir')
            mkdir(outputDir);
        end

        for j = 1:length(tsvFiles)
            rawCovariates = tdfread(fullfile(tsvFiles(j).folder, tsvFiles(j).name));

            T = table(rawCovariates.trans_x, rawCovariates.trans_y, rawCovariates.trans_z, ...
                      rawCovariates.rot_x, rawCovariates.rot_y, rawCovariates.rot_z);

            for k = 4:6
                T{:,k} = T{:,k} ./ 50;
            end

            [~, name, ~] = fileparts(tsvFiles(j).name);
            regressor_filename = strrep(name, 'desc-confounds_regressors', 'motionRegressors');

            writetable(T, fullfile(outputDir, [regressor_filename '.txt']), 'Delimiter', ' ', 'WriteVariableNames', false);
        end
    end
    fprintf('   ...motion regressors extracted for all subjects.\n\n');

    %==========================================================================
    %% SPECIFY MODEL
    %==========================================================================
    fprintf('3. Specifying First-Level Models...\n');

    for i = 1:length(subjects)
        current_subject_id = subjects{i};
        subject_taskInfo = subject_config(current_subject_id, taskInfo);

        curSubj.behavDir = fullfile(directory.Project, current_subject_id, rawData.behavDir);
        curSubj.behavFile = dir(fullfile(curSubj.behavDir, [current_subject_id '*' subject_taskInfo.Name '*.tsv']));

        curSubj.directory = fullfile(directory.Model, current_subject_id);
        if ~isdir(curSubj.directory)
            mkdir(curSubj.directory);
        end

        fprintf('   Processing subject %s with %d runs...\n', current_subject_id, subject_taskInfo.Runs);

        if isempty(curSubj.behavFile)
            fprintf('   ERROR: No behavioral files found for %s. Skipping.\n', current_subject_id);
            continue;
        end

        for curRun = 1:subject_taskInfo.Runs
            fprintf('      Reading behavioral data for run %d...\n', curRun);

            BehavData = readtable(fullfile(curSubj.behavDir, curSubj.behavFile(curRun).name), 'FileType', 'text');

            onsets = num2cell(BehavData.onset)';
            durations = num2cell(BehavData.duration)';
            names = BehavData.trial_type';

            trialsOfInterest = ~strcmp(names, 'no_interest');
            onsets = onsets(trialsOfInterest);
            durations = durations(trialsOfInterest);
            names = names(trialsOfInterest);

            matfilename = fullfile(curSubj.directory, sprintf('Run%03d_multiple_conditions.mat', curRun));
            save(matfilename, 'names', 'onsets', 'durations');
        end
    end
    fprintf('   ...model specification complete for all subjects.\n\n');

    % Save the parameters file needed for the next step
    param_filename = fullfile(directory.Analysis, 'params_for_downstream.mat');
    save(param_filename, 'directory', 'rawData', 'preprocPipeline', 'taskInfo', 'Model', 'Mask', 'Func', 'subjects', 'analysisType', 'regressRT');
    fprintf('Parameters saved to: %s\n\n', param_filename);

    fprintf('--- Unified First-Level Setup Finished ---\n');
    fprintf('You may now run estimateModel.m (after loading params_for_downstream.mat).\n');
end
