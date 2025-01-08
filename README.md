# OpenAI and Ollama Clients

Check current process information
```nushell
ai-session
```
Modify current process context
```nushell
ai-switch-model
ai-switch-provider
ai-switch-temperature
```

Configuration
```nushell
ai-config-upsert-prompt [prompt]
ai-config-upsert-provider [provider]
ai-config-upsert-function [function]
```

Interactive conversation
```nushell
ai-chat
ai-history-chat
```

One-shot conversation based on prompt
```nushell
[msg] | ai-do <prompt> ...<placeholder>
ai-history-do
```

Embedding
```nushell
ai-embed
```

## Function call

```nushell
"Choose a function call: Will it rain tomorrow? I'm in San Francisco."
| ai-do general en -f [get_current_weather] -m <model support fuction call>
| to yaml
```

Results:
```yaml
- id: call_20250108110159e36662a911f84245_0
  index: 0
  type: function
  function:
    name: get_current_weather
    arguments: '{"location": "San Francisco, CA", "unit": "fahrenheit"}'
```

- If you're unsure what prompt to use, you can use `general`.
- In edit mode, you can execute `ai-editor-run` incrementally in the editor (For example, execute `:terminal` in Vim).
- The `-f` parameter is a list of callable functions. Based on your message, the LLM will choose one to call and provide the appropriate parameters.
- In this example, even without the `Choose a function call: ` prompt, it might still successfully call the function and output both the message and `tool_calls` (in most cases, only `tool_calls` are needed).
- Use `ai-config-upsert-function` to add your own functions.

### Call nu function
```nushell
'get all svc' | ai-do general en -t [kube-get ssh kube-log kube-edit]
# kube-get  svc --all

'get all deployment in app' | ai-do general en -t [kube-get ssh kube-log kube-edit]
# kube-get  deployment --namespace app

'edit pod app in xxx' | ai-do general en -t [kube-get ssh kube-log kube-edit]
# kube-edit  pod --namespace xxx  app
```

- Nushell does not yet support dynamic function calls. Using `nu -c` might cause some modules not to load, so for now, it only prints commands.

- Calling a complete function to generate an enum will also fail:
  - Module loading issues
  - Many complete functions are hidden by default
  - There may be significant overhead involved, which requires consideration of caching

## Configure with the `ai config`.

```nushell
{
    name: deepseek
    baseurl: 'https://api.deepseek.com/v1'
    model_default: 'deepseek-coder'
    api_key: sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
    org_id: ''
    project_id: ''
    temp_max: 1.5
} | ai-config-upsert-provider

{
    name: git-diff-summary-xxx
    system: ('_: |-
        ## Goals
        Extract commit messages from the `git diff` output

        ## Constraints
        summarize only the content changes within files, ignore changes in hashes, and generate a title based on these summaries.

        ## Attention
        - Lines starting with `+` indicate new lines added.
        - Lines starting with `-` indicate deleted lines.
        - Other lines are context and are not part of the current change being described.
        - Output in {{lang}}
        ' | from yaml | get _)
    template: "```\n{{}}\n```"
    placeholder: '
        lang:
          en: English
          fr: French
          es: Spanish
          de: German
          ru: Russian
          ar: Arabic
          zh: Chinese
          ja: Janpanese
          ko: Korean
        '
    description: 'Summarize from git differences'
} | ai-config-upsert-prompt
```

---
[Others](https://github.com/fj0r/nushell/blob/main/README.md)
