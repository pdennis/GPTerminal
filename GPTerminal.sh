#!/usr/bin/env bash

# Ensure that necessary tools are installed
if ! command -v curl >/dev/null 2>&1; then
    echo "Error: curl is not installed."
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is not installed."
    exit 1
fi

# Check if OPENAI_API_KEY is set
if [ -z "$OPENAI_API_KEY" ]; then
    echo "Error: OPENAI_API_KEY environment variable is not set."
    exit 1
fi

# Get the task from the user
echo "Please enter the task for the model:"
read task

# Set the initial prompt
read -r -d '' initial_prompt << EOM
You are a large language model in control of a computer via a command line. Your outputs will be directly entered into the command line and executed. The terminal outputs will be piped back here. (Don't worry, it's all within a secure VM, so nothing you do can actually harm my underlying system -- it's an experiment).

Your output should only contain a single command you want to run. This command can be long, for example if you need to pipe an entire script into a file. But the output should be only the command you want run, not even markdown code characters should be included -- whatever you output will be sent verbatim to the terminal. Break the task down into small tasks where possible, rather than making long commands with multiple pipes or ampersands. 

The commands and output so far are as follows (if blank, this is the first command):

If the information sent back to you indicates that the task is complete, output only the word TASKCOMPLETE3939
EOM

# Initialize variables
commands_and_outputs=""
loop_counter=0
max_loops=30
task_complete=false

# Loop until task is complete or max loops reached
while [ $loop_counter -lt $max_loops ] && [ "$task_complete" = false ]; do
    # Increment loop counter
    loop_counter=$((loop_counter + 1))

    # Build the prompt to send to the model
    prompt="${initial_prompt}\n\nTask: ${task}\n\n${commands_and_outputs}"

    # Prepare the JSON data for the API call
    json_data=$(jq -n --arg prompt "$prompt" \
      '{model: "gpt-4o-mini", messages: [{role: "user", content: $prompt}], temperature: 0, max_tokens: 1000}')

    # Call the OpenAI API
    response=$(curl -s https://api.openai.com/v1/chat/completions \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $OPENAI_API_KEY" \
      -d "$json_data")

    # Check for errors in the API response
    if [ -z "$response" ]; then
        echo "Error: Empty response from OpenAI API."
        exit 1
    fi

    # Extract the model's output (the command to run)
    command_to_run=$(echo "$response" | jq -r '.choices[0].message.content' | sed 's/^ *//;s/ *$//')

    # Check if the model output TASKCOMPLETE3939
    if [ "$command_to_run" = "TASKCOMPLETE3939" ]; then
        echo "Task complete."
        task_complete=true
        break
    fi

    # Sanitize the command_to_run (remove any line breaks)
    command_to_run=$(echo "$command_to_run" | tr -d '\n\r')

    # Execute the command in the VM (modify this section to run in your VM)
    echo "Executing command: $command_to_run"
    command_output=$(eval "$command_to_run" 2>&1)

    # Append the command and output to the commands_and_outputs
    commands_and_outputs="${commands_and_outputs}\n\nCommand: ${command_to_run}\nOutput:\n${command_output}"

done

if [ "$task_complete" = false ]; then
    echo "Task not completed within $max_loops iterations."
fi

