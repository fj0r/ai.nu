# Use AI in Nushell

## Summary

nu.ai is a collection of Nushell commands to help you create composable and interactive LLM tools. It brings the power of Nushell (composable succinct commands) to LLM tool development.

nu.ai uses Nushell's SQLite native integration to persist providers, settings and LLM interactions.

[![asciicast](https://asciinema.org/a/ZIIq9lzcEtT5b3rPaHpZdJgKj.svg)](https://asciinema.org/a/ZIIq9lzcEtT5b3rPaHpZdJgKj)
[![asciicast](https://asciinema.org/a/Qd8sHfvdjoCA0o7c2poKO8RT9.svg)](https://asciinema.org/a/Qd8sHfvdjoCA0o7c2poKO8RT9)
[![asciicast](https://asciinema.org/a/keIWUPQev6K9qZ0FGDzeQCEpk.svg)](https://asciinema.org/a/keIWUPQev6K9qZ0FGDzeQCEpk)

## Why?

There are many AI clients available on the market, but most of them are web-based UIs or local UIs. While these UIs are relatively user-friendly for beginners, they can be inefficient for advanced users. For example, in `ai.nu`, you can run the following command:

```bash
git diff | ai-do git-diff-summary zh | git commit -m $in
```

This command generates a summary of Git changes and uses it as the commit message. If you use this command frequently, you can further simplify or automate it. Additionally, you can use `Ctrl+r` to quickly search through your history of commands.

However, in a web UI, you would need to follow these steps:
- Run `git diff`
- Copy the output
- Paste it into the UI
- Press Enter and wait for the result
- Copy the result
- Paste it into IDE
- Manually commit

These steps are cumbersome and require you to focus on each step to ensure you click in the right place.
Worse still, these steps cannot be saved or automated, and deploying something like an "auto-clicker" tool would encounter issues such as window position changes, which are inherent flaws of GUIs.

While some AI clients offer CLI versions, using Bash for programming is not ideal; its syntax is complex and confusing.

## Commands

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
ai-assistant
ai-history-assistant
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

## Getting Started

### Prerequisites

- Nushell (current version)
- Either Ollama installed locally, OpenAI API key, Deepseek API key, any OpenAI compliant API

### Installation

Since [unpm](https://github.com/nushell/nupm) might not be mature enough yet. Let's install nu.ai manually.

Nushell:

```nushell
git clone --depth=1 https://github.com/fj0r/ai.nu.git ~/nu_libs/ai.nu
$"(char newline)$env.NU_LIB_DIRS ++= glob ~/nu_libs/*" | save -a $nu.env-path
$"(char newline)use ai *" | save -a $nu.config-path
exec nu
```

Bash:
```bash
git clone --depth=1 https://github.com/fj0r/ai.nu.git ~/nu_libs/ai.nu
if [ -z "${XDG_CONFIG_HOME}" ]; then
    # If not set, set it to the default value (~/.config)
    export XDG_CONFIG_HOME="${HOME}/.config"
fi
mkdir -p $XDG_CONFIG_HOME/nushell/
echo \$env.NU_LIB_DIRS ++= glob \~/nu_libs/\* | tee -a $XDG_CONFIG_HOME/nushell/env.nu
echo use ai \* | tee -a $XDG_CONFIG_HOME/nushell/config.nu
```
Notes:

- Looks for $XDG_CONFIG_HOME, and if not found, we set the value
- Points Nushell to look for our downloaded modules in env.nu
- Loads all ai.nu commands by default when you start Nushell
- The next time you launch Nushell, you should be able to run `ai-session`

### First Call to Ollama

This section assumes you have Ollama installed locally. Manually execute the following:

```bash
#install Ollama - https://ollama.com/download
#curl -fsSL https://ollama.com/install.sh | sh

# see if you have any models running - `ollama stop <model>` if running
ollama list
ollama pull llama3.2

# perform a quick test using the cli
ollama run llama3.2
```

Note that Ollama running llama3.2 is the ai.nu default provider; therefore, the following should magically work.

Launch `nu` and make your first call using the LLM one-shot command `ai-do`:

```nu
"what is nushell" | ai-do general en
```

Where:

- "what is nushell" is the prompt
- `ai-do` is the ai.nu command
- `general` is the name of the system prompt for your one-shot call
- `en` is the language to use

Note that ai.nu includes auto-complete options. This means that you can `ai-do <tab>` to see a list of all prompts, and you can `ai-do general <tab>` to see a list of all languages.

You can see a history of your one-shot prompts using `ai-history-do`.

Launch `nu` again. This time let's engage in a conversation using the LLM chat command `ai-chat`. You are placed into a REPL session where you can interactively converse with llama3.2. Type `\q` to quit the REPL. Execute `ai-history-chat` to see your chat history.

### First Call to OpenAI

This section assumes you have an OpenAI API key.

To see the 'current' provider, execute `ai-session`.

To see a list of existing providers, execute `ai-switch-provider <tab>`. After pressing <tab>, you will be prompted with all available providers. Choosing a provider set the values seen in `ai-sesson`.

To edit an existing provider, execute `ai-config-upsert-provider <tab>`. After choosing your provider, you will be placed into an editor where you can make changes. Save your changes and close your editor. Note that editing a provider does not promote this provider to the be the current.

To load a new provider:

```nu
{
    name: openai
    baseurl: 'https://api.openai.com/v1'
    model_default: 'gpt-4o'
    api_key: sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
    org_id: ''
    project_id: ''
    temp_max: 1.0
} | ai-config-upsert-provider
```

Where `--batch` tells ai.nu to accept these values without prompting the user with an editor.

Once you have created your provider and you can see the appropriate values in `ai-session`, you can repeat the steps in the above Ollama section.

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
'what applications are currently running?' | ai-do general en -t [kube-get ssh kube-log kube-edit]
# kube-get  pods --namespace default --all

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
