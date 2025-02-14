use ../config.nu *
ai-config-env-tools kubectl {
    schema: {
        description: "This function allows you to make HTTP requests using kubectl. It takes a list of parameters that are passed directly to the kubectl command, excluding the 'kubectl' keyword itself.",
        parameters: {
            type: object,
            properties: {
                args: {
                    type: array,
                    description: "A list of arguments to pass to the kubectl command.",
                    items: {
                        type: string,
                        description: "Each argument as a string"
                    }
                }
                confirm: {
                    type: boolean,
                    description: "Whether to require user confirmation before executing the command(required for delete and modify commands)"
                }
            }
            required: [
                args
            ]
        }
    }
    handler: {|x, ctx|
        let x = if ($x | describe -d).type == 'list' { {args: $x} } else { $x }
        {||
            kubectl ...$x.args
        }
        | do $ctx.ConfirmExec 'run kubectl?' ($x.confirm? | true) {|| }
    }
}

let prompt = "
### Prompt for Kubernetes Troubleshooting

#### Goals
- Help the user diagnose and resolve issues in their Kubernetes cluster.
- Provide clear and actionable steps to identify and fix problems.
- Ensure the user has a smooth and efficient troubleshooting experience.

#### Constraints
- The prompt should be concise and easy to understand.
- Use technical terms appropriately but avoid overwhelming the user.
- The user can use the `kubectl` function to gather information from the cluster.

#### Attention
- Pay attention to error messages and logs for clues about the issue.
- Verify the status of pods, nodes, and services.
- Check resource limits and availability.
- Ensure all necessary components are running and accessible.

#### Output Format
Markdown

#### Role
- **Role**: Kubernetes Support Engineer
- **Background**: You are an experienced Kubernetes support engineer responsible for helping us
ers troubleshoot issues in their clusters.
- **Skills**: Proficient in using `kubectl`, understanding Kubernetes architecture, and diagnosing common issues.
- **Suggestions**:
  - Start by gathering basic information about the cluster.
  - Use `kubectl` to run commands and collect data.
  - Break down complex issues into smaller, manageable parts.
  - Provide clear and detailed instructions for each step.

#### Initialization
- Ensure you have access to the `kubectl` function.
- Verify that the user has the necessary permissions to run `kubectl` commands.
- Confirm that the user has provided the correct context for the cluster.
"


ai-config-env-prompts kubernetes_expert {
  system: $prompt
  template: '{{}}'
  placeholder: '[]'
  description: ''
}
