function run_first_level_setup()
    % A unified script for the first level setup of the multi-FRAME pipeline.
    %
    % This script combines the functionality of createParams, preprocessData, and
    % specifyModel to provide a seamless and robust setup for the first-level
    % analysis. It dynamically discovers the number of runs for each subject.
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
    %% DEFINE PARAMETERS
    %==========================================================================
    fprintf('1. Defining Parameters...\n');

    % --- USER SETTINGS --- %
    subject_numbers = [101 102 104:108 110:128 130 133:143 146 148 151 152 154:157 159 160 162:166 170 171 ...
        402:426 428:435 437:440 442:448 450:458 460 ...
        202:203 206:210 215:218 221:223 226:230 233 236 237 239 243:245 248:257 259 261 266 ...
        501:510 512 513 516 518:534 536:542 544 545 547:562];
    subjects = cellfun(@(x) sprintf('sub-%d', x), num2cell(subject_numbers), 'UniformOutput', false);

    directory.Project = '/home/acclab/Desktop/axc';
    taskInfo.Name = 'retrieval';
    taskInfo.Conditions = {'cr_new', 'hit_same', 'fa_sim', 'cr_sim'};
    Model.TR    = 0.8;
    Func.prefix = 'w';

    % DEB: Define analysisType and regressRT, which were missing
    analysisType = 'ROI'; % Options: 'ROI' or 'Searchlight'
    regressRT.flag = 'No'; % Options: 'Yes' or 'No'

    % --- Less frequently changed parameters --- %
    rawData.funcDir = fullfile(directory.Project, 'derivatives', 'fmriprep');
    rawData.behavDir = 'beh';
    preprocPipeline = 'fmriprep';
    Model.units = 'secs';
    Mask.on   = 0;
    directory.Analysis = fullfile(directory.Project, 'multivariate');
    directory.Model = fullfile(directory.Analysis, 'models', ['SingleTrialModel' taskInfo.Name]);

    fprintf('   ...parameters defined successfully.\n\n');

    %==========================================================================
    %% SETUP AND SPECIFY MODELS (Combines preprocessData and specifyModel)
    %==========================================================================
    fprintf('2. Setting up models and extracting regressors...\n');

    for i = 1:length(subjects)
        current_subject_id = subjects{i};

        % --- Automatic Run Discovery --- %
        behav_dir = fullfile(directory.Project, current_subject_id, rawData.behavDir);
        behav_files = dir(fullfile(behav_dir, [current_subject_id '*' taskInfo.Name '*.tsv']));
        num_runs = length(behav_files);

        if num_runs == 0
            fprintf('   WARNING: No behavioral files found for %s in %s. Skipping.\n', current_subject_id, behav_dir);
            continue;
        end
        fprintf('   Processing subject %s with %d discovered runs...\n', current_subject_id, num_runs);

        % --- Regressor Extraction (from preprocessData) --- %
        fmri_func_dir = fullfile(rawData.funcDir, current_subject_id, 'func');
        confound_files = dir(fullfile(fmri_func_dir, ['*' taskInfo.Name '*confound*.tsv']));

        model_dir = fullfile(directory.Model, current_subject_id);
        if ~exist(model_dir, 'dir')
            mkdir(model_dir);
        end

        for j = 1:length(confound_files)
            rawCovariates = tdfread(fullfile(confound_files(j).folder, confound_files(j).name));
            T = table(rawCovariates.trans_x, rawCovariates.trans_y, rawCovariates.trans_z, ...
                      rawCovariates.rot_x, rawCovariates.rot_y, rawCovariates.rot_z);
            for k = 4:6, T{:,k} = T{:,k} ./ 50; end

            [~, name, ~] = fileparts(confound_files(j).name);
            regressor_filename = strrep(name, 'desc-confounds_regressors', 'motionRegressors');
            writetable(T, fullfile(model_dir, [regressor_filename '.txt']), 'Delimiter', ' ', 'WriteVariableNames', false);
        end

        % --- Model Specification (from specifyModel) --- %
        for curRun = 1:num_runs
            BehavData = readtable(fullfile(behav_dir, behav_files(curRun).name), 'FileType', 'text');

            onsets = num2cell(BehavData.onset)';
            durations = num2cell(BehavData.duration)';
            names = BehavData.trial_type';

            trialsOfInterest = ~strcmp(names, 'no_interest');
            onsets = onsets(trialsOfInterest);
            durations = durations(trialsOfInterest);
            names = names(trialsOfInterest);

            matfilename = fullfile(model_dir, sprintf('Run%03d_multiple_conditions.mat', curRun));
            save(matfilename, 'names', 'onsets', 'durations');
        end
    end
    fprintf('   ...model setup complete for all subjects.\n\n');

    %==========================================================================
    %% SAVE PARAMETERS FOR DOWNSTREAM SCRIPTS
    %==========================================================================
    param_filename = fullfile(directory.Analysis, 'params_for_downstream.mat');
    % DEB: Add missing variables 'analysisType' and 'regressRT' to the save command
    save(param_filename, 'directory', 'rawData', 'preprocPipeline', 'taskInfo', 'Model', 'Mask', 'Func', 'subjects', 'analysisType', 'regressRT');
    fprintf('3. Parameters saved to: %s\n\n', param_filename);

    fprintf('--- Unified First-Level Setup Finished ---\n');
    fprintf('You may now run estimateModel.m (it will load params from the saved file).\n');
end
