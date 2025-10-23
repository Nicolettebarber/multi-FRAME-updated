function convert_behavioral_data()
    % Converts raw behavioral data from .xlsx files to BIDS-compliant .tsv files.
    %
    % This script reads raw behavioral data from individual subject .xlsx files,
    % processes it, recodes trial types, and saves it as a set of BIDS-compliant
    % _events.tsv files in the subject's 'beh' directory, ready for use with
    % the multi-FRAME pipeline.
    %
    % Key Features:
    % - User-configurable settings at the top of the script.
    % - Automatically detects the number of runs from the data.
    % - Safely backs up existing .tsv files before overwriting.
    % - Preserves all original columns from the source Excel file.

    clear; clc;

    % --- USER SETTINGS --- %

    % Define the list of subject numbers to process.
    % Example: [101, 102, 201:205]
    selected_subjects = [101, 102];

    % Define the base directory for the project.
    base_dir = '/home/acclab/Desktop/axc';

    % Define the directory where the raw .xlsx behavioral files are stored.
    behav_source_dir = fullfile(base_dir, 'raw_behavioral_MST');

    % Set to true to back up existing .tsv files, or false to overwrite them directly.
    create_backups = true;

    % --- END USER SETTINGS --- %

    fprintf('Starting behavioral data conversion process...\n\n');

    % Process each selected subject
    for sub_num = selected_subjects
        fprintf('--- Processing subject %d ---\n', sub_num);

        % Path to the subject's source Excel file
        excel_path = fullfile(behav_source_dir, sprintf('%d.xlsx', sub_num));

        % Check if the source file exists
        if ~exist(excel_path, 'file')
            fprintf('WARNING: Skipping subject %d (file not found: %s)\n\n', sub_num, excel_path);
            continue;
        end

        % Load data from the Excel file
        try
            data = readtable(excel_path);
        catch ME
            fprintf('ERROR: Could not read Excel file for subject %d. Skipping. Error: %s\n\n', sub_num, ME.message);
            continue;
        end

        % Automatically determine the number of runs based on the 'Run' column
        if ~ismember('Run', data.Properties.VariableNames)
            fprintf('ERROR: "Run" column not found in Excel file for subject %d. Skipping.\n\n', sub_num);
            continue;
        end
        unique_runs = unique(data.Run);
        num_runs = length(unique_runs);
        fprintf('Found %d runs for subject %d.\n', num_runs, sub_num);

        % Create the subject's 'beh' directory if it doesn't exist
        beh_sub_dir = fullfile(base_dir, sprintf('sub-%03d', sub_num), 'beh');
        if ~exist(beh_sub_dir, 'dir')
            mkdir(beh_sub_dir);
            fprintf('Created directory: %s\n', beh_sub_dir);
        end

        % Process each run found in the data
        for run_idx = 1:num_runs
            run = unique_runs(run_idx);

            % Extract trials for this run
            run_data = data(data.Run == run, :);

            % Create BIDS-compatible table
            bids_table = table();

            % 1. Add onset and duration
            bids_table.onset = run_data.StartT;
            bids_table.duration = run_data.EndT - run_data.StartT;

            % 2. Recode trial_type
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

            % 3. Preserve all additional original columns
            original_cols = run_data.Properties.VariableNames;
            for col_name_cell = original_cols
                col_name = col_name_cell{:};
                if ~ismember(col_name, {'onset', 'duration', 'trial_type'})
                    bids_table.(col_name) = run_data.(col_name);
                end
            end

            % Generate BIDS-compliant filename
            events_filename = sprintf('sub-%03d_task-retrieval_run-%d_events.tsv', sub_num, run);
            beh_file_path = fullfile(beh_sub_dir, events_filename);

            % Backup existing file if it exists and backups are enabled
            if exist(beh_file_path, 'file') && create_backups
                backup_path = [beh_file_path '.bak'];
                movefile(beh_file_path, backup_path);
                fprintf('Backed up existing file to: %s\n', backup_path);
            end

            % Save the new .tsv file
            writetable(bids_table, beh_file_path, 'FileType', 'text', 'Delimiter', '\t');
            fprintf('Saved new behavioral file: %s\n', beh_file_path);
        end
        fprintf('Completed processing for subject %d.\n\n', sub_num);
    end

    disp('--- All processing complete. ---');
end
