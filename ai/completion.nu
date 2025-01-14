use sqlite.nu *
use data.nu

export def cmpl-models [ctx] {
    let provider = if NU_ARGX_EXISTS in $env {
        $ctx | argx parse | get opt.provider?
    }
    let s = data session -p $provider
    http get --headers [
        Authorization $"Bearer ($s.api_key)"
        OpenAI-Organization $s.org_id
        OpenAI-Project $s.project_id
    ] $"($s.baseurl)/models"
    | get data.id
}

export def cmpl-tools [] {
    $env.OPENAI_TOOLS | columns
}

export def cmpl-nu-function [] {
    scope commands | get name
}

export def cmpl-previous [] {
    let rw = (term size).columns - 22
    sqlx $"select id as value,
            substr\(
                updated || '│' ||
                type || '|' ||
                printf\('%-20s', args\) || '│' ||
                model || '|' ||
                content,
                0, ($rw)
            \) as description
        from scratch order by updated desc limit 10;"
    | { completions: $in, options: { sort: false } }
}

export def 'cmpl-role' [ctx] {
    let args = $ctx | split row '|' | last | str trim -l | split row ' ' | range 1..
    let len = $args | length
    match $len {
        1 => {
            sqlx "select name as value, description from prompt"
        }
        _ => {
            let d = sqlx $"select * from prompt where name = '($args.0)'"
            let d = $d | first | get placeholder | from yaml
            let pos = $len - 2
            $d | get ($d | columns | get $pos) | columns
        }
    }
}


def cmpl-config [context] {
    let ctx = $context | split row -r '\s+' | range 1..
    if ($ctx | length) < 2 {
        return [provider, prompt, function]
    } else {
        sqlx $'select name from ($ctx.0)' | get name
    }
}

export def cmpl-provider [] {
    let current = sqlx $"select provider from sessions where created = '($env.OPENAI_SESSION)'"
    | get provider
    sqlx $'select name, active from provider'
    | each {|x|
        let a = if $x.active > 0 {'*'} else {''}
        let c = if $x.name in $current {'+'} else {''}
        {value: $x.name, description: $"($c)($a)"}
    }
}

export def cmpl-prompt [] {
    sqlx $"select name from prompt"
    | get name
}

export def cmpl-system [] {
    sqlx $"select name from prompt where system != ''"
    | get name
}

export def cmpl-temperature [] {
    let s = data session
    let tr = ($s.temp_max - $s.temp_min) / 5
    0..5 | each { $in * $tr }
}
