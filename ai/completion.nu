use sqlite.nu *
use data.nu

export def cmpl-models [] {
    let s = data session
    http get --headers [
        Authorization $"Bearer ($s.api_key)"
        OpenAI-Organization $s.org_id
        OpenAI-Project $s.project_id
    ] $"($s.baseurl)/models"
    | get data.id
}

export def cmpl-function [] {
    run $'select name from function' | get name
}

export def cmpl-previous [] {
    run $"select id as value, updated || '│' || type || '|' || args || '│' ||  model as description
        from scratch order by updated desc limit 10;"
}

export def 'cmpl-role' [ctx] {
    let args = $ctx | split row '|' | last | str trim -l | split row ' ' | range 1..
    let len = $args | length
    match $len {
        1 => {
            run "select name as value, description from prompt"
        }
        _ => {
            let d = run $"select * from prompt where name = '($args.0)'"
            $d | first | get placeholder | from json | get ($len - 2) | columns
        }
    }
}


export def cmpl-config [context] {
    let ctx = $context | split row -r '\s+' | range 1..
    if ($ctx | length) < 2 {
        return [provider, prompt, function]
    } else {
        run $'select name from ($ctx.0)' | get name
    }
}

export def cmpl-provider [] {
    let current = run $"select provider from sessions where created = '($env.OPENAI_SESSION)'"
    | get provider
    run $'select name, active from provider'
    | each {|x|
        let a = if $x.active > 0 {'*'} else {''}
        let c = if $x.name in $current {'+'} else {''}
        {value: $x.name, description: $"($c)($a)"}
    }
}

export def cmpl-prompt [] {
    run $"select name from prompt"
    | get name
}

export def cmpl-system [] {
    run $"select name from prompt where system != ''"
    | get name
}

export def cmpl-temperature [] {
    let s = data session
    let tr = ($s.temp_max - $s.temp_min) / 5
    0..5 | each { $in * $tr }
}
