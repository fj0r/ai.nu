OpenAI and Ollama Clients

Check current process information
ai-session
```
Modify current process context
```
ai-switch-model
ai-switch-provider
ai-switch-temperature
```

Configuration
```
ai-config-upsert-prompt [prompt]
ai-config-upsert-provider [provider]
ai-config-upsert-function [function]
```

Interactive conversation
```
ai-chat
ai-history-chat
```

One-shot conversation based on prompt
```
[msg] | ai-do <prompt> ...<placeholder>
ai-history-do
```

Embedding
```
ai-embed
```

Configure with the `ai config`.
```
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
