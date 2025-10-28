function run_dartel_normalization()
    % Applies DARTEL normalization to fMRIPrep outputs without smoothing.
    %
    % This script is designed to take preprocessed functional data from fMRIPrep,
    % apply a DARTEL template to normalize the images to MNI space, and save
    % the output with a 'w' prefix. It does not apply any smoothing.
    %
    % Key features:
    % - Robustly handles subjects with a variable number of runs.
    % - Skips subjects who already have the output 'w' files.
    % - Skips subjects who are missing the necessary DARTEL flowfield file.

    clear; clc;

    % --- USER SETTINGS --- %
    subs = [101:102]; % Example: [101:105, 201, 203]
    base_dir = '/home/acclab/Desktop/axc/derivatives';
    template_path = fullfile(base_dir, 'matlab/spm/DARTEL_templates/Full_MST/Template_AxCFull_6.nii');
    fmri_file_prefix = 'w'; % The prefix for the output functional files

    % --- END USER SETTINGS --- %

    % Initialize SPM
    spm('defaults', 'FMRI');
    spm_jobman('initcfg');

    % Process each subject in parallel
    parfor i = 1:length(subs)
        sub = subs(i);
        sub_id_str = sprintf('sub-%03d', sub);
        fprintf('\nStarting Subject: %s\n', sub_id_str);

        func_dir = fullfile(base_dir, 'fmriprep', sub_id_str, 'func');
        flowfield_path = fullfile(base_dir, 'fmriprep', sub_id_str, 'anat', ...
            sprintf('u_rc1%s_desc-preproc_T1w_Template_AxCFull.nii', sub_id_str));

        if ~exist(flowfield_path, 'file')
            fprintf('WARNING: Flowfield missing for %s, skipping...\n', sub_id_str);
            continue;
        end

        % Find all existing (non-w-prefixed) functional runs for this subject
        input_files_struct = dir(fullfile(func_dir, ...
            sprintf('%s_task-retrieval_run-*_space-MNI152NLin2009cAsym_desc-preproc_bold.nii', sub_id_str)));

        if isempty(input_files_struct)
            fprintf('WARNING: No input functional files found for %s, skipping...\n', sub_id_str);
            continue;
        end

        num_runs = length(input_files_struct);

        % Check if all output 'w' files for the existing runs already exist
        w_files_exist_count = 0;
        for run = 1:num_runs
            % Note: SPM creates the run number from the filename, not a simple index
            [~, fname, ~] = fileparts(input_files_struct(run).name);
            run_num_str = regexp(fname, 'run-(\d+)', 'tokens');
            if ~isempty(run_num_str)
                run_num = str2double(run_num_str{1});
                output_file = fullfile(func_dir, sprintf('%s%s_task-retrieval_run-%d_space-MNI152NLin2009cAsym_desc-preproc_bold.nii', fmri_file_prefix, sub_id_str, run_num));
                if exist(output_file, 'file')
                    w_files_exist_count = w_files_exist_count + 1;
                end
            end
        end

        if w_files_exist_count == num_runs
             fprintf('Skipping %s (all %d w-prefixed files already exist)\n', sub_id_str, num_runs);
             continue;
        end

        fprintf('Found %d runs to process for %s.\n', num_runs, sub_id_str);

        input_files = cell(num_runs, 1);
        for run = 1:num_runs
            input_files{run} = fullfile(func_dir, input_files_struct(run).name);
        end

        matlabbatch = [];
        matlabbatch{1}.spm.tools.dartel.mni_norm.template = {template_path};
        matlabbatch{1}.spm.tools.dartel.mni_norm.data.subj.flowfield = {flowfield_path};
        matlabbatch{1}.spm.tools.dartel.mni_norm.data.subj.images = input_files;
        matlabbatch{1}.spm.tools.dartel.mni_norm.vox = [2.3 2.3 2.3];
        matlabbatch{1}.spm.tools.dartel.mni_norm.preserve = 0;
        matlabbatch{1}.spm.tools.dartel.mni_norm.fwhm = [0 0 0];

        try
            spm_jobman('run', matlabbatch);

            fprintf('Successfully processed %s\n', sub_id_str);

        catch ME
            fprintf('ERROR processing %s: %s\n', sub_id_str, ME.message);
        end
    end

    fprintf('\nProcessing complete!\n');
    fprintf('All new `%s` files saved in their respective `fmriprep/sub-*/func/` directories.\n', fmri_file_prefix);
end
