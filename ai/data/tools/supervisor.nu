export-env {
    let f = {
        name: delegate_tasks
        description: "This function allows the AI supervisor to delegate tasks to subordinates based on user intent. It analyzes the user's request, selects the appropriate subordinate, and generates the necessary parameters for the task."
        parameters: {
            type: object
            properties: {
                instructions: {
                    type: string,
                    description: "A clear and concise set of instructions for the task."
                }
                subordinate_name: {
                    type: string
                    description: "The name of the subordinate to which the task will be delegated. Must be a pre-defined subordinate name"
                }
                options: {
                    type: array
                    description: "A list of options. The number and order of options must match the options's declaration."
                    items: {
                        type: string
                        description: "Each options must be one of the pre-defined enums for the specific options."
                    }
                }
                tools: {
                    type: array
                    description: "A list of tools that might be used by the subordinate to complete the task."
                    items: {
                        type: string
                        description: "Each tool must be a pre-defined tool name."
                    }
                }
            }
            required: [
                instructions
                subordinate_name
            ]
        }
    }
    const p = path self .
    let p = open ([$p supervisor.txt] | path join)
    $env.AI_CONFIG = $env.AI_CONFIG | merge { assistant: {
        prompt: $p
        function: $f
        filled: false
    } }
}
