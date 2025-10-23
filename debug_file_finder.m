function debug_file_finder()
    % This is a diagnostic script to debug file finding in the multi-FRAME pipeline.
    % It mimics the logic of specifyModel.m to help identify why behavioral
    % files are not being found for a specific subject.

    clear; clc;

    % --- USER SETTINGS --- %
    % Please set these variables to match the subject that is failing.

    subject_to_debug = 'sub-101'; % The subject ID as a string

    % These should match the settings in your createParams.m file
    project_dir = '/home/acclab/Desktop/axc';
    task_name = 'retrieval';
    behav_dir_name = 'beh';
    behav_file_ext = '.tsv';

    % --- END USER SETTINGS --- %

    fprintf('--- Starting File Finder Debugger ---\n\n');

    % 1. Construct the path to the behavioral directory
    behav_dir_path = fullfile(project_dir, subject_to_debug, behav_dir_name);
    fprintf('1. Constructed behavioral directory path:\n   %s\n\n', behav_dir_path);

    % Check if this directory exists
    if exist(behav_dir_path, 'dir')
        fprintf('   [SUCCESS] This directory exists.\n\n');
    else
        fprintf('   [ERROR] This directory does NOT exist. Please check the path.\n\n');
        return;
    end

    % 2. Construct the file search pattern (wildcard)
    search_pattern = [subject_to_debug, '*', task_name, '*', behav_file_ext];
    full_search_path = fullfile(behav_dir_path, search_pattern);
    fprintf('2. Constructed full file search path (wildcard):\n   %s\n\n', full_search_path);

    % 3. Execute the search command
    fprintf('3. Executing the file search (the ''dir'' command)...\n\n');
    found_files = dir(full_search_path);

    % 4. Analyze the results
    if isempty(found_files)
        fprintf('   [RESULT] The search returned an EMPTY list.\n');
        fprintf('   This is the cause of the error.\n');
        fprintf('   Please double-check that the search pattern from step 2 matches the actual filenames.\n\n');
    else
        fprintf('   [RESULT] The search was SUCCESSFUL. It found the following %d files:\n', length(found_files));
        for i = 1:length(found_files)
            fprintf('   - %s\n', found_files(i).name);
        end
        fprintf('\n   If you see this message, the file-finding logic is correct, and the error may be elsewhere.\n\n');
    end

    fprintf('--- Debugger Finished ---\n');

end
