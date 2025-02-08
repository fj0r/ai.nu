export-env {
    $env.AI_TOOLS = $env.AI_TOOLS | merge {
        router: {
            schema: {
                description: "This function dispatches an execution based on a prompt template and associated parameters. It requires a template name, a list of placeholders, and optionally, a set of tools that may be needed for the execution.",
                parameters: {
                    type: object
                    properties: {
                        query: {
                            type: string,
                            description: "The search terms or keywords"
                        }
                        template_name: {
                            type: string
                            description: "The name of the prompt template to be used."
                        }
                        placeholders: {
                            type: array
                            description: "A list of placeholders. Each value should align with the template's defined placeholder."
                            items: {
                                type: string
                            }
                        }
                        tools: {
                            type: array
                            description: "[Optional] A list of tools that might be required for the execution of the template."
                            items: {
                                type: string
                            }
                        }
                    }
                    required: [
                        query
                        template_name
                        placeholders
                    ]
                }
            }
            handler: {|x, config| print ($x | table -e) }
        }
    }
    let p = "_: |-
    ### Goals
    You are an AI assistant capable of completing various tasks.
    Some tasks require more detailed prompts template to execute.
    Below is a template of prompts:
    ```
    {{templates}}
    ```

    The placeholder tokens in the prompts must strictly adhere to their definitions, and the number of placeholders should match the defined number. The values for the placeholders should use the values from the enumeration, and consider the tools that may be needed when performing the task.

    Below is a placeholders:
    ```
    {{placeholders}}
    ```

    Below is a list of available tools:
    ```
    {{tools}}
    ```
    ### Constraints
    - Placeholder parameters must strictly match those defined in the template.
    - The order of the placeholders in the parameters should match the order defined in the template.
    - The value for each placeholder should be selected from the enum in the template.
    - Tools listed should be considered for use during task execution.
    - Only the router function can be called; if there isn't enough information to fill in the parameters, continue asking questions.


    ### Attention
    - It's not mandatory to run the prompts template
    - Ensure placeholders are correctly replaced with values from the given enumeration.
    - Pay attention to the inclusion of appropriate tools to assist in the task.
    " | from yaml | get _
    $env.AI_CONFIG = $env.AI_CONFIG | merge { assistant: $p }
}
