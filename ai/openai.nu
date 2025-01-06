use sqlite.nu *
use common.nu *
use completion.nu *
use data.nu
export use config.nu *

export-env {
    $env.OPENAI_SESSION = date now | format date '%FT%H:%M:%S.%f'
    data init
    data make-session $env.OPENAI_SESSION
}

export def ai-send [
    message: string = '{}'
    --model(-m): string@cmpl-models
    --system: string
    --function(-f): list<string@cmpl-function>
    --image(-i): path
    --forget(-f)
    --placehold(-p): string = '{}'
    --out(-o)
    --tag: string = ''
    --debug
] {
    let content = $in | default ""
    let content = $message | str replace -m $placehold $content
    let s = data session
    let model = if ($model | is-empty) { $s.model } else { $model }
    data record $s.created $s.provider $model 'user' $content 0 $tag
    let sys = if ($system | is-empty) { [] } else { [{role: "system", content: $system}] }
    let req = if $forget {
        if ($image | is-empty) {
            [{ role: "user", content: $content }]
        } else {
            let img = if ($image | path exists) {
                let b =  open $image | encode base64
                let t = $image | path parse | get extension | str downcase
                let t = match $t {
                    'jpg' | 'jpeg' => 'jpeg'
                    _ => $t
                }
                {url: $"data:image/($t);base64,($b)"}
            } else {
                $image
            }
            [{
                role: "user"
                content: [
                    {
                        type: text
                        text: $content
                    }
                    {
                        type: image_url
                        image_url: $img
                    }
                ]
            }]
        }
    } else {
        data messages
    }
    let tools = if ($function | is-not-empty) {
        let f = sqlx $"select name, description, parameters from function
            where name in \(($function | each { Q $in } | str join ', ' )\)"
        let f = $f | each {|i|
            let i = $i | update parameters {|x| $x.parameters | from yaml }
            {
                type: function
                function: $i
            }
        }
        { tools: $f }
    } else {
        {}
    }
    let req = {
        model: $model
        messages: [...$sys ...$req]
        temperature: $s.temperature
        stream: true
        ...$tools
    }
    if $debug {
        let xxx = [
            '' 'message' $message
            'placeholder' $placehold
            'content' $content
        ] | str join "\n------\n"
        print $"(ansi grey)($xxx)(ansi reset)"
        print $"======req======"
        print $"(ansi grey)($req | table -e)(ansi reset)"
    }
    let r = http post -t application/json --headers [
        Authorization $"Bearer ($s.api_key)"
    ] $"($s.baseurl)/chat/completions" $req
    | lines
    | reduce -f {msg: '', token: 0} {|i,a|
        let x = $i | parse -r '.*?(?<data>\{.*)'
        if ($x | is-empty) { return $a }
        let x = $x | get 0.data | from json
        if 'tool_calls' in $x.choices.0.delta {
            let c = $a
            | insert tool_calls $x.choices.0.delta.tool_calls
            | update token {|x| $x.token + 1 }
            return $c
        }
        let m = $x.choices | each { $in.delta.content } | str join
        if not $out {
            print -n $m
        }
        $a
        | update msg {|x| $x.msg + $m }
        | update token {|x| $x.token + 1 }
    }
    data record $s.created $s.provider $model 'assistant' $r.msg $r.token $tag
    if ($function | is-not-empty) {
        return $r.tool_calls
    }
    if $out { $r.msg }
}

export def ai-chat [
    --model(-m): string@cmpl-models
    --system: string@cmpl-system
] {
    let s = data session
    let model = if ($model | is-empty) { $s.model } else { $model }
    let system = if ($system | is-empty) { '' } else {
        sqlx $"select system from prompt where name = '($system)'"
        | get 0.system
    }
    let p = $'😎 '
    let ci = ansi grey
    let cr = ansi reset
    let cm = ansi yellow
    let nl = char newline
    mut model = $model
    mut system = $system
    while true {
        let a = input $"($ci)($p)"
        let l = $a | split row -r '\s+'
        match ($l | first) {
            '\q' | 'exit' | 'quit' => { break }
            '\model' => { $model = $l | last }
            '\system' => { $system = $l | last }
            _ => {
                print -n $"✨ ($cm)"
                ai-send -m $model --system $system $a
                print $cr
            }
        }
    }
}

export def ai-editor-run [] {
    let ctx = $env.AI_EDITOR_CONTEXT | from nuon
    if $ctx.action == 'ai-do' {
        let c = open -r $ctx.file
        if ($c | is-empty) {
            print $"(ansi grey)no content, ignore(ansi reset)"
        } else {
            $c | ai-do ...$ctx.args
        }
    }
}

export def ai-do [
    ...args: string@cmpl-role
    --out(-o)
    --model(-m): string@cmpl-models
    --function(-f): list<string@cmpl-function>
    --image(-i): path
    --previous(-p): int@cmpl-previous
    --debug
] {
    let input = $in
    let input = if ($input | is-empty) {
        if ($previous | is-not-empty) {
            sqlx $"select content from scratch where id = ($previous)" | get 0.content
        } else {
            ''
        }
        | block-edit $"($args | str join '_').XXX.temp" --context {
            action: ai-do
            args: $args
        }
        | tee {
            sqlx $"insert into scratch \(type, args, content, model\) values \('ai-do', (Q ($args | str join ' ')), (Q $in), (Q $model)\)"
        }
    } else {
        $input
    }
    let s = data session
    let role = sqlx $"select * from prompt where name = '($args.0)'" | first
    let placehold = $"<(random chars -l 6)>"

    let pls = $role.placeholder | from yaml
    let val = $pls | columns
    | zip ($args | range 1..)
    | reduce -f {} {|i,a|
        $a
        | insert $"($i.0):" $i.1
        | insert ($i.0 | into string) ($pls | get $i.0 | get $i.1)
    }

    let prompt = $role.template | render {_: $placehold, ...$val}
    let system = if ($role.system | is-not-empty) {
        $role.system | render $val
    }

    $input | (
        ai-send -p $placehold
        --system $system
        --function $function
        --image $image
        --tag ($args | str join ',')
        --forget
        --out=$out
        --debug=$debug
        -m $model
        $prompt
    )
}

export def ai-loop [
    ...args: string@cmpl-role
    --model(-m): string@cmpl-models
    --function(-f): list<string@cmpl-function>
] {
    loop {
        let tf = mktemp -t ai-loop-XXXX
        ^$env.EDITOR $tf
        let c = open $tf --raw
        rm -f $tf
        $c | ai-do ...$args -m $model -f $function
        print $"\n(ansi grey)------(ansi reset)"
        input
    }
}

export def ai-embed [
    input: string
    --model(-m): string@cmpl-models
] {
    let s = data session
    let model = if ($model | is-empty) { $s.model } else { $model }
    http post -t application/json $"($s.baseurl)/embeddings" {
        model: $model, input: [$input], encoding_format: 'float'
    }
    | get data.0.embedding
}

export def 'similarity cosine' [a b] {
    if ($a | length) != ($b | length) {
        print "The lengths of the vectors must be equal."
    }
    $a | zip $b | reduce -f {p: 0, a: 0, b: 0} {|i,a|
        {
            p: ($a.p + ($i.0 * $i.1))
            a: ($a.a + ($i.0 * $i.0))
            b: ($a.b + ($i.1 * $i.1))
        }
    }
    | $in.p / (($in.a | math sqrt) * ($in.b | math sqrt))
}
