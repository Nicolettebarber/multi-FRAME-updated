function estimateModel()
    % Estimates a GLM specified by the output of run_first_level_setup.m
    %
    % This script dynamically determines the number of runs for each subject
    % by counting the number of multiple conditions files. It then estimates
    % the first-level model using SPM.
    %
    % Before running:
    % 1. Ensure you have run run_first_level_setup.m successfully.
    % 2. Ensure SPM is in your MATLAB path.

    clear; clc;
    fprintf('--- Starting Model Estimation ---\n\n');

    %==========================================================================
    %% LOAD PARAMETERS
    %==========================================================================
    fprintf('1. Loading Parameters...\n');

    % Find the parameters file in the multivariate directory
    analysis_dir = '/home/acclab/Desktop/axc/multivariate'; % DEB: Hardcoded for simplicity
    params_file = fullfile(analysis_dir, 'params_for_downstream.mat');

    if ~exist(params_file, 'file')
        error('Could not find params_for_downstream.mat. Please run run_first_level_setup.m first.');
    end
    load(params_file);
    fprintf('   ...parameters loaded successfully from %s.\n\n', params_file);

    %==========================================================================
    %% ESTIMATE MODELS
    %==========================================================================
    fprintf('2. Estimating First-Level Models for each subject...\n');

    spm('Defaults','FMRI');
    spm_jobman('initcfg');

    for curSub = 1:length(subjects)
        current_subject_id = subjects{curSub};
        Model.directory = fullfile(directory.Model, current_subject_id);

        % --- Automatic Run Discovery --- %
        SpecModelMats = dir(fullfile(Model.directory, 'Run*_multiple_conditions.mat'));
        num_runs = length(SpecModelMats);

        if num_runs == 0
            fprintf('   WARNING: No model specification files found for %s. Skipping.\n', current_subject_id);
            continue;
        end
        fprintf('   Processing subject %s with %d discovered runs...\n', current_subject_id, num_runs);

        motionFiles = dir(fullfile(Model.directory, '*.txt'));
        procFuncFiles = dir(fullfile(directory.Project, 'derivatives', 'fmriprep', current_subject_id, 'func', [Func.prefix '*' taskInfo.Name '*_bold.nii']));
        destDir = fullfile(directory.Model, current_subject_id);

        for i = 1:num_runs
            sourceFile = fullfile(procFuncFiles(i).folder, procFuncFiles(i).name);
            copyfile(sourceFile, destDir);

            Model.runs{i}.scans = {fullfile(destDir, procFuncFiles(i).name)};
            Model.runs{i}.multicond = fullfile(Model.directory, SpecModelMats(i).name);
            Model.runs{i}.motion = fullfile(motionFiles(i).folder, motionFiles(i).name);
        end

        % --- SPM Job Configuration --- %
        matlabbatch = [];
        matlabbatch{1}.spm.stats.fmri_spec.dir = {Model.directory};
        matlabbatch{1}.spm.stats.fmri_spec.timing.units = Model.units;
        matlabbatch{1}.spm.stats.fmri_spec.timing.RT = Model.TR;
        matlabbatch{1}.spm.stats.fmri_spec.timing.fmri_t = 16;
        matlabbatch{1}.spm.stats.fmri_spec.timing.fmri_t0 = 1;

        for curRun = 1:num_runs
            matlabbatch{1}.spm.stats.fmri_spec.sess(curRun).scans = Model.runs{curRun}.scans;
            matlabbatch{1}.spm.stats.fmri_spec.sess(curRun).cond = struct('name', {}, 'onset', {}, 'duration', {}, 'tmod', {}, 'pmod', {});
            matlabbatch{1}.spm.stats.fmri_spec.sess(curRun).multi = {Model.runs{curRun}.multicond};
            matlabbatch{1}.spm.stats.fmri_spec.sess(curRun).regress = struct('name', {}, 'val', {});
            matlabbatch{1}.spm.stats.fmri_spec.sess(curRun).multi_reg = {Model.runs{curRun}.motion};
            matlabbatch{1}.spm.stats.fmri_spec.sess(curRun).hpf = 128;
        end

        matlabbatch{1}.spm.stats.fmri_spec.fact = struct('name', {}, 'levels', {});
        matlabbatch{1}.spm.stats.fmri_spec.bases.hrf.derivs = [0 0];
        matlabbatch{1}.spm.stats.fmri_spec.volt = 1;
        matlabbatch{1}.spm.stats.fmri_spec.global = 'None';
        matlabbatch{1}.spm.stats.fmri_spec.mask = {''};
        matlabbatch{1}.spm.stats.fmri_spec.cvi = 'AR(1)';

        matlabbatch{2}.spm.stats.fmri_est.spmmat(1) = cfg_dep('fMRI model specification: SPM.mat File', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','spmmat'));
        matlabbatch{2}.spm.stats.fmri_est.write_residuals = 0;
        matlabbatch{2}.spm.stats.fmri_est.method.Classical = 1;

        % --- Run the SPM job --- %
        try
            spm_jobman('run', matlabbatch);
        catch ME
            fprintf('   ERROR processing SPM job for %s: %s. Skipping.\n', current_subject_id, ME.message);
            continue;
        end

        % --- File Cleanup --- %
        for i = 1:num_runs
            tempFile = fullfile(destDir, procFuncFiles(i).name);
            if exist(tempFile, 'file'), delete(tempFile); end
        end

        modelFiles = dir(fullfile(destDir, '*.nii'));
        for i = 1:length(modelFiles)
            gzip(fullfile(destDir, modelFiles(i).name));
            delete(fullfile(destDir, modelFiles(i).name));
        end

        load(fullfile(Model.directory, 'SPM.mat'));
        for i=1:length(SPM.Vbeta)
            SPM.Vbeta(i).fname = strrep(SPM.Vbeta(i).fname,'nii','nii.gz');
        end
        save(fullfile(Model.directory, 'SPM_gz.mat'),'SPM');

        % Clear runs for next subject
        Model = rmfield(Model,'runs');
    end

    fprintf('\n--- Model Estimation Finished ---\n');
end
