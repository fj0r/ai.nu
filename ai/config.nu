use sqlite.nu *
use common.nu *
use completion.nu *
use data.nu *

export def ai-session [] {
    data session
}

export def ai-history-chat [] {
    run $"select session_id, role, content, created from messages where session_id = (Q $env.OPENAI_SESSION) and tag = ''"
}

export def ai-history-do [num=10] {
    run $"select session_id, role, content, created from messages where tag = 'tool' order by created desc limit (Q $num)"
    | reverse
}

export def ai-history-scratch [num=10 --search(-s):string] {
    let s = if ($search | is-empty) { '' } else { $"where content like '%($search)%'" }
    run $"select id, type, args, model, content from scratch ($s) order by updated desc limit ($num)"
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
        run $"select * from provider where name = (Q $name)" | get -i 0
    }
    $x | upsert-provider --delete=$delete --action {|config|
        let o = $in
        if $batch {
            $o
        } else {
            $o
            | to yaml
            | $"# ($config.pk| str join ', ') is the primary key, do not modify it\n($in)"
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
        run $"select * from prompt where name = (Q $name)" | get -i 0
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

export def ai-config-upsert-function [
    name?: string@cmpl-function
    --delete
    --batch
] {
    let x = if ($name | is-empty) {
        $in | default {}
    } else {
        run $"select * from prompt where name = (Q $name)" | get -i 0
    }
    $x | upsert-function --delete=$delete --action {|config|
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

export def ai-change-temperature [
    o: string@cmpl-temperature
    --global(-g)
] {
    if $global {
        run $"update provider set temp_default = '($o)'
            where name = \(select provider from sessions where created = '($env.OPENAI_SESSION)'\)"
    }
    run $"update sessions set temperature = '($o)'
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
        run $"update provider set active = 0;"
        run $"update provider set active = 1 where name = (Q $o);"
    }
    run $"update sessions set provider = (Q $o),
        model = \(select model_default from provider where name = (Q $o)\)
        where created = (Q $env.OPENAI_SESSION)"
}

export def ai-change-model [
    model: string@cmpl-models
    --global(-g)
] {
    if $global {
        run $"update provider set model_default = (Q $model)
            where name = \(select provider from sessions where created = (Q $env.OPENAI_SESSION)\)"
    }
    run $"update sessions set model = (Q $model)
        where created = (Q $env.OPENAI_SESSION)"
}


