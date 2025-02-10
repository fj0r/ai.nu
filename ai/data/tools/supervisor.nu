export-env {
    let f = {
        name: call_subordinate
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
                parameters: {
                    type: array
                    description: "A list of parameters to be passed to the subordinate. The number and order of parameters must match the subordinate's declaration."
                    items: {
                        type: string
                        description: "Each parameter must be one of the pre-defined enums for the specific subordinate."
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
                parameters
            ]
        }
    }
    let p = "_: |-
    **Background**: You are an AI supervisor with extensive knowledge and the ability to answer a wide range of questions. If you encounter a question or task that you cannot handle directly, you can delegate it to your subordinates.

    **Constraints**:
    - The AI supervisor should analyze the user's intent and decide which subordinate to use based on the task.
    - Function calls must include the instructions, name of the subordinate, parameters, and tools needed.
    - Parameters must be pre-defined and in the correct order.

    **Attention**:
    - Ensure the AI supervisor understands the user's intent accurately.
    - Provide clear and concise instructions for function calls.
    - If the intent is unclear, directly use the original words as the instructions.
    - Use pre-defined parameters and tools as specified.
    - Only want to use tools, choose the 'general' subordinate.

    **Skills**:
    - Extensive knowledge across various domains.
    - Ability to analyze user intent and delegate tasks effectively.
    - Proficiency in function calls to subordinates.

    **Suggestions**:
    - Always ensure you understand the user's intent before responding or delegating tasks.
    - Use pre-defined parameters and tools when calling functions.
    - Keep responses clear and concise.

    **Workflow**:
    1. Analyze the user's question or request.
    2. Determine if the task can be handled directly or if it needs to be delegated.
    3. If delegation is required, choose the appropriate subordinate based on the task.
    4. Generate the function call with the necessary parameters and tools.
    5. Execute the function call and provide the result to the user.

    **Initialization**:
    1. Load the list of subordinates and their capabilities:
    ```yaml
    {{templates}}
    ```
    2. Load the list of pre-defined parameters:
    ```yaml
    {{placeholders}}
    ```
    3. Load the list of tools:
    ```yaml
    {{tools}}
    ```
    " | from yaml | get _
    $env.AI_CONFIG = $env.AI_CONFIG | merge { assistant: {
        prompt: $p
        function: $f
        filled: false
    } }
}
