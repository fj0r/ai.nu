OpenAI and Ollama Clients

`ai-session`

`ai-chat`
`ai-history-chat`

`ai-do <prompt> ...<placeholder>`
`ai-history-do`

`ai-embed`

`ai-change-model`
`ai-change-provider`
`ai-change-temperature`

Configure with the `ai config`.
```
ai-config-add-provider {
    name: deepseek
    baseurl: 'https://api.deepseek.com/v1'
    model_default: 'deepseek-coder'
    api_key: sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
    org_id: ''
    project_id: ''
    temp_max: 1.5
}

ai-config-add-prompt {
    name: 'git-diff-summary'
    template: "Extract commit logs from git differences, summarizing only the content changes in files while ignoring hash changes, and generate a title:\n```\n{}\n```"
    placeholder: ''
    description: 'Summarize from git differences'
}

ai-config-add-prompt {
    name: 'bilingual-translation'
    template: "The following content may be in {} or {}, identify which language it belongs to and translate it into the another.\nDo not explain what language it is, just provide the translation.\n```\n{}\n```"
    placeholder: [
        {
            en: English
        }
        {
            zh: Chinese
            jp: Japanese
        }
    ]
    description: ''
}
```
