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
    let p = open ([$p index.txt] | path join)
    $env.AI_CONFIG.assistant = {
        prompt_template: $p
        function: $f
        filled: false
        merge: {|d|
            let prompt = $env.AI_CONFIG.assistant.prompt_template
            | str replace '{{prompts}}' ($d.prompt | rename -c {placeholder:  options}  | to yaml)
            | str replace '{{placeholders}}' ($d.placeholder | to yaml)
            | str replace '{{tools}}' ($d.function | to yaml)
            let function = $env.AI_CONFIG.assistant.function
            | merge deep {
                parameters: {
                    properties: {
                        subordinate_name: {
                            enum: $d.prompt.name
                        }
                        options: {
                            properties: ($d.placeholder | reduce -f {} {|i,a|
                                $a | merge {
                                    $i.name: {
                                        type: string
                                        description: $i.description?
                                        enum: ($i.enum | columns)
                                    }
                                }
                            })
                        }
                        tools: {
                            items: {
                                enum: $d.function.name
                            }
                        }
                    }
                }
            }
            let filled = true
            {
                data: {
                    ...$d
                    getter: {
                        message: instructions
                        prompt: subordinate_name
                        placeholder: options
                        tools: tools
                    }
                }
                prompt: $prompt
                function: $function
                filled: $filled
            }
        }
    }
}
