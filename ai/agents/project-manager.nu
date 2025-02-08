$env.AI_TOOLS = $env.AI_TOOLS | merge {
  query_job_requirements: {
        config: {
            embedding: {
                url: 'http://172.178.5.123:11434/v1/embeddings'
            }
            surreal: {
                url: 'http://surreal.s/sql'
                ns: 'foo'
                db: 'foo'
                token: 'Zm9vOmZvbw=='
            }
        }
        schema: {
          "description": "This function allows you to query job responsibilities and requirements. It returns related employees/team and job duties based on the provided job content or requirements.",
          "parameters": {
            "type": "object",
            "properties": {
              "job_content": {
                "type": "string",
                "description": "The specific job content or requirements to query"
              },
              "department": {
                "type": "string",
                "description": "The department to filter the search within"
              },
              "role_type": {
                "type": "string",
                "description": "The type of role to filter the search within",
                "enum": [
                  "manager",
                  "developer",
                  "analyst",
                  "designer"
                ]
              }
            },
            "required": [
              "job_content"
            ]
          }
        }
        handler: {|x, config|
          open ~/.cache/employee.yaml
        }
    }
    get_ticket_counts_by_usernames: {
      schema: {
        "name": "get_ticket_counts_by_usernames",
        "description": "This function retrieves the number of tickets assigned to each employee based on a list of usernames and sorts them by the number of tickets in ascending order.",
        "parameters": {
          "type": "object",
          "properties": {
            "usernames": {
              "type": "array",
              "items": {
                "type": "string"
              },
              "description": "A list of usernames for which to retrieve ticket counts."
            }
          },
          "required": [
            "usernames"
          ]
        }
      }
      handler: {|x, config|
      }
    }
}

let prompt = '
### Goals
- Break down the task into smaller components.
- Allocate these components to relevant personnel.
- Ensure that the tasks are assigned to individuals who have fewer current assignments.
- Set reasonable deadlines for each task.

### Constraints
- Use a database to query the relevant personnel information.
- Assign tasks in a way that balances the workload among team members.
- Each task must have a clear and achievable deadline.

### Attention
- Pay attention to the current workload of each team member to avoid overloading anyone.
- Ensure that the deadlines set for each task are realistic and achievable.
- Keep track of the progress of each task to ensure timely completion.

### OutputFormat
Markdown

### Workflow
1. **Task Breakdown**:
   - Identify the main components of the task.
   - Estimate the time required for each component.
2. **Query Personnel Information**:
   - Access the database to retrieve information about the team members.
   - Review their current workload.
3. **Assign Tasks**:
   - Allocate tasks to team members with fewer current assignments.
   - Ensure that the workload is balanced.
4. **Set Deadlines**:
   - Assign reasonable deadlines for each task based on its complexity and the availability of the team member.
5. **Monitor Progress**:
   - Track the progress of each task.
   - Provide support and adjustments as needed.
'

{
  name: project-manager
  system: $prompt
  template: '{{}}'
  placeholder: '{}'
  description: ''
} | ai-config-upsert-prompt

ai-config-alloc-tools project-manager -t [get_current_time, query_job_requirements, get_ticket_counts_by_usernames]