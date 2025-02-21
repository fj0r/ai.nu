export-env {
    let f = {
        name: delegate_tasks
        description: "This function allows the AI supervisor to delegate tasks to subordinates based on user intent. It analyzes the user's request, selects the appropriate subordinate, and generates the necessary parameters for the task."
        parameters: {
            type: object
            properties: {
                instructions: {
                    type: string,
                    description: "Clear and concise steps and instructions for the subordinate to follow."
                }
                subordinate_name: {
                    type: string
                    description: "The name of the subordinate to which the task will be delegated."
                }
                options: {
                    type: object
                    properties: {
                      lang: {
                        type: string
                        description: "The language in which the response should be provided."
                        enum: [en fr es de ru ar zh ja ko]
                      },
                    }
                }
                tools: {
                    type: array
                    description: "A list of tools that might be used by the subordinate to complete the task."
                    items: {
                        type: string
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
        prompt_template: $p
        function: $f
        filled: false
    } }
}
