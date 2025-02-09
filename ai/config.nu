use sqlite.nu *
use common.nu *
use completion.nu *
use data.nu *

export def ai-session [--all(-a)] {
    data session
    | if $all { $in } else { $in | reject api_key }
}

export def ai-history-assistant [--num(-n):int = 1000] {
    data messages $num
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

export def ai-config-upsert-provider [
    name?: string@cmpl-provider
    --delete
    --batch
] {
    let x = if ($name | is-empty) {
        $in | default {}
    } else {
        sqlx $"select * from provider where name = (Q $name)" | get -i 0
    }
    $x | upsert-provider --delete=$delete --action {|config|
        let o = $in
        if $batch {
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
    --batch
] {
    let x = if ($name | is-empty) {
        $in | default {}
    } else {
        sqlx $"select * from prompt where name = (Q $name)" | get -i 0
    }
    $x | upsert-prompt --delete=$delete --action {|config|
        let o = $in
        if $batch {
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

export def ai-config-alloc-tools [
    name: string@cmpl-prompt
    --tools(-t): list<string@cmpl-tools>
    --purge(-p)
] {
    if $purge {
        sqlx $"delete from prompt_tools where prompt = (Q $name) returning tool;"
        | get tool
    } else {
        let v = $tools | each { $"\((Q $name), (Q $in)\)" } | str join ', '
        sqlx $"insert or replace into prompt_tools \(prompt, tool\) values ($v);"
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
    o: string@cmpl-provider
    --global(-g)
] {
    if $global {
        let tx = $"BEGIN;
            update provider set active = 0;
            update provider set active = 1 where name = '($o)';
            COMMIT;"
        sqlx $"update provider set active = 0;"
        sqlx $"update provider set active = 1 where name = (Q $o);"
    }
    sqlx $"update sessions set provider = (Q $o),
        model = \(select model_default from provider where name = (Q $o)\)
        where id = ($env.AI_SESSION)"
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


