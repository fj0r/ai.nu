use ../config.nu *
ai-config-env-tools call_kubectl {
    schema: {
        name: call_kubectl,
        description: "This function allows you to dynamically generate and execute kubectl commands. It supports various operations such as creating, deleting, and modifying Kubernetes resources. For any commands that involve deletion or modification, user confirmation is required.",
        parameters: {
            type: object,
            properties: {
                command: {
                    type: string,
                    description: "The main kubectl command (e.g., 'create', 'delete', 'get', 'apply')"
                },
                resource_type: {
                    type: string,
                    description: "The type of resource to operate on (e.g., 'pod', 'deployment', 'service')"
                },
                resource_name: {
                    type: string,
                    description: "The name of the specific resource (optional for some commands)"
                },
                flags: {
                    type: array,
                    items: {
                        type: string,
                        description: "Additional flags to pass to the kubectl command (e.g., '--namespace', '--context')"
                    },
                    description: "List of additional flags to pass to the kubectl command"
                },
                confirm: {
                    type: boolean,
                    description: "Whether to require user confirmation before executing the command(required for delete and modify commands)"
                }
            },
            required: [
                command,
                resource_type,
                confirm
            ]
        }
    }
    handler: {|x, config|
        if $x.confirm {
            let r = if ($x.resource_name? | is-not-empty) { [$x.resource_name] } else { [] }
            let f = if ($x.flags? | is-not-empty) { $x.flags } else { [] }
            kubectl $x.command $x.resource_type ...$r ...$x.flags
        }
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
- The user can use the `call_kubectl` function to gather information from the cluster.

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
- **Skills**: Proficient in using `kubectl`, understanding Kubernetes architecture, and diagnos
ing common issues.
- **Suggestions**:
  - Start by gathering basic information about the cluster.
  - Use `call_kubectl` to run commands and collect data.
  - Break down complex issues into smaller, manageable parts.
  - Provide clear and detailed instructions for each step.

#### Workflow
1. **Gather Initial Information**
   - Ask the user to provide details about the issue they are facing.
   - Use `call_kubectl` to get an overview of the cluster:
     ```sh
     call_kubectl get all --all-namespaces
     ```
2. **Check Pod Statuses**
   - Identify any pods that are not running as expected.
   - Use `call_kubectl` to describe the problematic pod:
     ```sh
     call_kubectl describe pod <pod-name> -n <namespace>
     ```
3. **Examine Logs**
   - Retrieve logs from the problematic pod to look for error messages:
     ```sh
     call_kubectl logs <pod-name> -n <namespace>
     ```
4. **Verify Node Health**
   - Check the status of all nodes in the cluster:
     ```sh
     call_kubectl get nodes
     ```
   - Describe any nodes that appear unhealthy:
     ```sh
     call_kubectl describe node <node-name>
     ```
5. **Check Resource Limits**
   - Ensure that there are no resource constraints affecting the pods:
     ```sh
     call_kubectl describe resourcequotas -n <namespace>
     call_kubectl describe limitranges -n <namespace>
     ```
6. **Review Service and Ingress Configurations**
   - Check if there are any issues with services or ingress controllers:
     ```sh
     call_kubectl get svc -n <namespace>
     call_kubectl get ingress -n <namespace>
     ```
7. **Provide Recommendations**
   - Based on the gathered information, suggest potential solutions or next steps.
   - Offer to run additional commands if needed.

#### Initialization
- Ensure you have access to the `call_kubectl` function.
- Verify that the user has the necessary permissions to run `kubectl` commands.
- Confirm that the user has provided the correct context for the cluster.
"


ai-config-env-prompts kubernetes_expert {
  system: $prompt
  template: '{{}}'
  placeholder: '[]'
  description: ''
}
