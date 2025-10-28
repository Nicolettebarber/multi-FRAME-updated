function convert_behavioral_data()
    % Converts raw behavioral data from .xlsx files to BIDS-compliant .tsv files.
    %
    % This script reads raw behavioral data from a single concatenated .xlsx file
    % for each subject. It dynamically determines the number of runs by finding
    % the actual fMRI data files, segments the behavioral data accordingly,
    % recodes trial types, and saves a set of BIDS-compliant _events.tsv files.
    %
    % Key Features:
    % - Automatically discovers the number of runs per subject, ensuring perfect
    %   alignment between functional and behavioral data.
    % - User-configurable settings at the top of the script.
    % - Safely backs up existing .tsv files before overwriting.

    clear; clc;

    % --- USER SETTINGS --- %

    selected_subjects = [101, 102, 201, 211]; % Example: [101, 102, 201:205, 211]

    run_indices = {
        2:90,   % Run 1
        92:180, % Run 2
        182:270, % Run 3
        272:360, % Run 4
        362:450  % Run 5 (Indices for a potential 5th run)
    };

    base_dir = '/home/acclab/Desktop/axc';
    behav_source_dir = fullfile(base_dir, 'raw_behavioral_MST');
    fmri_data_dir = fullfile(base_dir, 'derivatives', 'fmriprep');
    create_backups = true;

    % --- END USER SETTINGS --- %

    fprintf('Starting behavioral data conversion process...\n\n');

    % Process each selected subject
    for sub_num = selected_subjects
        sub_id_str = sprintf('sub-%d', sub_num);
        fprintf('--- Processing subject %s ---\n', sub_id_str);

        % --- Automatic Run Discovery --- %
        func_dir = fullfile(fmri_data_dir, sub_id_str, 'func');
        run_files = dir(fullfile(func_dir, sprintf('%s_task-retrieval_run-*_bold.nii.gz', sub_id_str)));
        num_runs = length(run_files);

        if num_runs == 0
            fprintf('WARNING: No functional run files found for %s in %s. Skipping.\n\n', sub_id_str, func_dir);
            continue;
        end
        fprintf('   Discovered %d functional runs for this subject.\n', num_runs);

        % --- Behavioral File Processing --- %
        excel_path = fullfile(behav_source_dir, sprintf('%d.xlsx', sub_num));

        if ~exist(excel_path, 'file')
            fprintf('WARNING: Skipping subject %d (behavioral file not found: %s)\n\n', sub_num, excel_path);
            continue;
        end

        try
            data = readtable(excel_path);
        catch ME
            fprintf('ERROR: Could not read Excel file for subject %d. Skipping. Error: %s\n\n', sub_num, ME.message);
            continue;
        end

        beh_sub_dir = fullfile(base_dir, sprintf('sub-%03d', sub_num), 'beh');
        if ~exist(beh_sub_dir, 'dir')
            mkdir(beh_sub_dir);
            fprintf('   Created directory: %s\n', beh_sub_dir);
        end

        % Process the discovered number of runs
        for run = 1:num_runs
            fprintf('   Processing Run %d...\n', run);

            if run > length(run_indices)
                fprintf('   ERROR: Not enough run_indices defined for run %d. Skipping run.\n', run);
                continue;
            end

            try
                run_data = data(run_indices{run}, :);
            catch ME
                fprintf('   ERROR: Could not extract trials for run %d. The Excel file may not have enough rows. Skipping run.\n', run);
                continue;
            end

            bids_table = table();
            bids_table.onset = run_data.StartT;
            bids_table.duration = run_data.EndT - run_data.StartT;

            if iscell(run_data.Resp)
                resp_numeric = cellfun(@str2double, run_data.Resp);
            else
                resp_numeric = run_data.Resp;
            end

            trial_types = cell(height(run_data), 1);
            for i = 1:height(run_data)
                cond = run_data.Cond{i};
                resp = resp_numeric(i);

                if strcmp(cond, 'TR') && resp == 1
                    trial_types{i} = 'hit_same';
                elseif strcmp(cond, 'TR') && resp == 2
                    trial_types{i} = 'miss_same';
                elseif strcmp(cond, 'TL') && resp == 1
                    trial_types{i} = 'fa_sim';
                elseif strcmp(cond, 'TL') && resp == 2
                    trial_types{i} = 'cr_sim';
                elseif strcmp(cond, 'TF') && resp == 1
                    trial_types{i} = 'fa_new';
                elseif strcmp(cond, 'TF') && resp == 2
                    trial_types{i} = 'cr_new';
                else
                    trial_types{i} = 'no_interest';
                end
            end
            bids_table.trial_type = trial_types;

            original_cols = run_data.Properties.VariableNames;
            for col_name_cell = original_cols
                col_name = col_name_cell{:};
                if ~ismember(col_name, {'onset', 'duration', 'trial_type'})
                    bids_table.(col_name) = run_data.(col_name);
                end
            end

            events_filename = sprintf('sub-%03d_task-retrieval_run-%d_events.tsv', sub_num, run);
            beh_file_path = fullfile(beh_sub_dir, events_filename);

            if exist(beh_file_path, 'file') && create_backups
                backup_path = [beh_file_path '.bak'];
                movefile(beh_file_path, backup_path);
            end

            writetable(bids_table, beh_file_path, 'FileType', 'text', 'Delimiter', '\t');
            fprintf('      Saved new behavioral file: %s\n', beh_file_path);
        end
        fprintf('   Completed processing for subject %d.\n\n', sub_num);
    end

    disp('--- All processing complete. ---');
end
