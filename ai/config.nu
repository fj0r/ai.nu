use sqlite.nu *
use common.nu *
use completion.nu *

export def ai-session [] {
    data session
}

export def ai-history-chat [] {
    open $env.OPENAI_DB
    | query db $"select session_id, role, content, created from messages where session_id = (Q $env.OPENAI_SESSION) and tag = ''"
}

export def ai-history-do [num=10] {
    open $env.OPENAI_DB
    | query db $"select session_id, role, content, created from messages where tag = 'tool' order by created desc limit (Q $num)"
    | reverse
}

export def ai-config-add-provider [o] {
    $o | select name baseurl api_key model_default org_id project_id temp_max
    | db-upsert --do-nothing $env.OPENAI_DB 'provider' 'name'
}

export def ai-config-add-prompt [o] {
    {system: '', placeholder: '', description: ''}
    | merge $o
    | update placeholder {|x| $x.placeholder | to json -r}
    | select name system template placeholder description
    | db-upsert --do-nothing $env.OPENAI_DB 'prompt' 'name'
}

export def ai-config-add-function [o] {
    {name: '', description: '', parameters: ''}
    | merge $o
    | update parameters {|x| $x.parameters | to json -r}
    | select name description parameters
    | db-upsert --do-nothing $env.OPENAI_DB 'function' 'name'
}

export def ai-config-edit [
    table: string@cmpl-config
    pk: string@cmpl-config
] {
    data edit $table $pk
}

export def ai-config-update-provider [name: string@cmpl-provider] {
    ai-config-edit provider $name
}

export def ai-config-update-prompt [name: string@cmpl-prompt] {
    open $env.OPENAI_DB
    | query db $"select * from prompt where name = (Q $name)"
    | first
    | update placeholder {|x| $x.placeholder | from json}
    | to yaml
    | block-edit $"update-prompt-($name).XXX.yml"
    | from yaml
    | update placeholder {|x| $x.placeholder | to json -r}
    | select name system template placeholder description
    | db-upsert $env.OPENAI_DB 'prompt' 'name'
}

export def ai-config-update-function [name: string@cmpl-function] {
    open $env.OPENAI_DB
    | query db $"select * from function where name = (Q $name)"
    | first
    | update parameters {|x| $x.parameters | from json}
    | to yaml
    | block-edit $"update-function-($name).XXX.yml"
    | from yaml
    | update parameters {|x| $x.parameters | to json -r}
    | select name description parameters
    | db-upsert $env.OPENAI_DB 'function' 'name'
}

export def ai-config-del-provider [
    name: string@cmpl-provider
] {
    open $env.OPENAI_DB | query db $'delete from provider where name = (Q $name)'
}

export def ai-config-del-prompt [
    name: string@cmpl-prompt
] {
    open $env.OPENAI_DB | query db $'delete from prompt where name = (Q $name)'
}

export def ai-change-temperature [
    o: string@cmpl-temperature
    --global(-g)
] {
    if $global {
        data query $"update provider set temp_default = '($o)'
            where name = \(select provider from sessions where created = '($env.OPENAI_SESSION)'\)"
    }
    data query $"update sessions set temperature = '($o)'
        where created = '($env.OPENAI_SESSION)'"
}

export def ai-change-provider [
    o: string@cmpl-provider
    --global(-g)
] {
    if $global {
        let tx = $"BEGIN;
            update provider set active = 0;
            update provider set active = 1 where name = '($o)';
            COMMIT;"
        data query $"update provider set active = 0;"
        data query $"update provider set active = 1 where name = (Q $o);"
    }
    data query $"update sessions set provider = (Q $o),
        model = \(select model_default from provider where name = (Q $o)\)
        where created = (Q $env.OPENAI_SESSION)"
}

export def ai-change-model [
    model: string@cmpl-models
    --global(-g)
] {
    if $global {
        data query $"update provider set model_default = (Q $model)
            where name = \(select provider from sessions where created = (Q $env.OPENAI_SESSION)\)"
    }
    data query $"update sessions set model = (Q $model)
        where created = (Q $env.OPENAI_SESSION)"
}


