use sqlite.nu *
use common.nu *
use completion.nu *
use data.nu *

export def ai-session [--all(-a)] {
    data session
    | if $all { $in } else { $in | reject api_key }
}

export def ai-history-assistant [--num(-n):int = 1000 --sql] {
    data messages --sql=$sql $num
}

export def ai-history-do [tag?: string@cmpl-prompt --num(-n):int] {
    mut w = []
    if ($tag | is-empty) {
        $w ++= ["tag != ''"]
    } else {
        $w ++= [$"tag like (Q $tag '%')"]
    }
    if ($num | is-empty) {
        $w ++= [$"session_id = ($env.AI_SESSION)"]
    }
    let w = if ($w | is-empty) {
        ""
    } else {
        $"where ($w | str join ' and ')"
    }
    let n = if ($num | is-not-empty) {
        $"limit (Q $num)"
    } else {
        ""
    }
    sqlx $"select session_id, role, content, tool_calls, tag, created from messages ($w) order by created desc ($n)"
    | reverse
}

export def ai-history-scratch [search?:string --num(-n)=10] {
    let s = if ($search | is-empty) { '' } else { $"where content like '%($search)%'" }
    sqlx $"select id, type, args, model, content from scratch ($s) order by updated desc limit ($num)"
    | reverse
}

export def --env ai-config-env-prompts [name, defs] {
    let defs = $defs | upsert name $name
    $env.AI_PROMPTS = $env.AI_PROMPTS | merge deep {$name: $defs}
}

export def --env ai-config-env-tools [name, defs] {
    let defs = $defs | merge deep {schema: {name: $name}}
    $env.AI_TOOLS = $env.AI_TOOLS | merge deep {$name: $defs}
}

export def ai-config-upsert-provider [
    name?: string@cmpl-provider
    --delete
] {
    let input = $in
    if ($name | is-empty) {
        $input | default {}
    } else {
        sqlx $"select * from provider where name = (Q $name)" | get -o 0
    }
    | upsert-provider --delete=$delete --action {|config|
        let o = $in
        if ($input | is-not-empty) {
            $o
        } else {
            $o
            | to yaml
            | $"# ($config.pk | str join ', ') is the primary key, do not modify it\n($in)"
            | block-edit $"upsert-provider-XXXXXX.yaml"
            | from yaml
        }
    }
}

export def ai-config-upsert-prompt [
    name?: string@cmpl-prompt
    --delete
] {
    let input = $in
    if ($name | is-empty) {
        {}
    } else {
        sqlx $"select * from prompt where name = (Q $name)" | get -o 0
    }
    | upsert-prompt --delete=$delete --action {|config|
        let o = $in
        if ($input | is-not-empty) {
            $o
        } else {
            $o
            | to yaml
            | $"# ($config.pk| str join ', ') is the primary key, do not modify it\n($in)"
            | block-edit $"upsert-config-XXXXXX.yaml"
            | from yaml
        }
    }
}

export def ai-config-upsert-model [
    name?: string@cmpl-models
    --delete
] {
    let input = $in
    if ($name | is-empty) {
        {}
    } else {
        sqlx $"select * from model where name = (Q $name)" | get -o 0 | default {}
    }
    | upsert-model --delete=$delete --action {|config|
        let o = $in
        if ($input | is-not-empty) {
            $o
        } else {
            $o
            | to yaml
            | $"# ($config.pk| str join ', ') is the primary key, do not modify it\n($in)"
            | block-edit $"upsert-model-XXXXXX.yaml"
            | from yaml
        }
    }
}

export def ai-config-alloc-tools [
    name: string@cmpl-prompt
    --tools(-t): list<string>@cmpl-tools
    --purge(-p)
] {
    if $purge {
        sqlx $"delete from prompt_tools where prompt = (Q $name) returning tool;"
        | get tool
    } else {
        {
            $name: $tools
        }
        | insert-prompt-tools
    }
}

export def ai-switch-temperature [
    o: string@cmpl-temperature
    --global(-g)
] {
    if $global {
        sqlx $"update provider set temp_default = '($o)'
            where name = \(select provider from sessions where id = ($env.AI_SESSION)\)"
    }
    sqlx $"update sessions set temperature = '($o)'
        where id = ($env.AI_SESSION)"
    ai-session
}

export def ai-switch-provider [
    provider: string@cmpl-provider
    model?: string@cmpl-models-pos
    --global(-g)
] {
    if $global {
        let tx = $"BEGIN;
            update provider set active = 0;
            update provider set active = 1 where name = '($provider)';
            COMMIT;"
        sqlx $"update provider set active = 0;"
        sqlx $"update provider set active = 1 where name = (Q $provider);"
    }
    sqlx $"update sessions set provider = (Q $provider),
        model = \(select model_default from provider where name = (Q $provider)\)
        where id = ($env.AI_SESSION)"
    if ($model | is-not-empty) {
        ai-switch-model --global=$global $model
    }
    ai-session
}

export def ai-switch-model [
    model: string@cmpl-models
    --global(-g)
] {
    if $global {
        sqlx $"update provider set model_default = (Q $model)
            where name = \(select provider from sessions where id = ($env.AI_SESSION)\)"
    }
    sqlx $"update sessions set model = (Q $model)
        where id = ($env.AI_SESSION)"
    ai-session
}


