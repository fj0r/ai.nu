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
    let img = if ($image | is-empty) {
        {}
    } else {
        {images: [(open $image | encode new-base64)]}
    }
    let s = data session
    let model = if ($model | is-empty) { $s.model } else { $model }
    data record $s.created $s.provider $model 'user' $content 0 $tag
    let sys = if ($system | is-empty) { [] } else { [{role: "system", content: $system}] }
    let req = if $forget {
        [{ role: "user", content: $content, ...$img }]
    } else {
        data messages
    }
    let function = if ($function | is-not-empty) {
        let f = run $"select name, description, parameters from function
            where name in \(($function | each { Q $in } | str join ', ' )\)"
        {function: $f}
    } else { {} }
    let req = {
        model: $model
        messages: [...$sys ...$req]
        temperature: $s.temperature
        stream: true
        ...$function
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
        let m = $x.choices | each { $in.delta.content } | str join
        print -n $m
        $a
        | update msg {|x| $x.msg + $m }
        | update token {|x| $x.token + 1 }
    }
    data record $s.created $s.provider $model 'assistant' $r.msg $r.token $tag
    if $out { $r.msg }
}

export def ai-chat [
    --model(-m): string@cmpl-models
    --system: string@cmpl-system
] {
    let s = data session
    let model = if ($model | is-empty) { $s.model } else { $model }
    let system = if ($system | is-empty) { '' } else {
        run $"select system from prompt where name = '($system)'"
        | get 0.system
    }
    let p = $'😎 '
    let ci = ansi grey
    let cr = ansi reset
    let cm = ansi yellow
    let nl = char newline
    while true {
        let a = input $"($ci)($p)"
        match $a {
            '\q' | 'exit' | 'quit' => { break }
            _ => {
                print -n $"✨ ($cm)"
                ai-send -m $model --system $system $a
                print $cr
            }
        }
    }
}


export def ai-do [
    ...args: string@cmpl-role
    --out(-o)
    --model(-m): string@cmpl-models
    --function(-f): list<string@cmpl-function>
    --previous(-p): int@cmpl-previous
    --debug
] {
    let input = $in
    let input = if ($input | is-empty) {
        if ($previous | is-not-empty) {
            run $"select content from scratch where id = ($previous)" | get 0.content
        } else {
            ''
        }
        | block-edit $"($args | str join '_').XXX.temp" | tee {
            run $"insert into scratch \(type, args, content, model\) values \('ai-do', (Q ($args | str join ' ')), (Q $in), (Q $model)\)"
        }
    } else {
        $input
    }
    let s = data session
    let role = run $"select * from prompt where name = '($args.0)'" | first
    let placehold = $"<(random chars -l 6)>"

    let pls = $role.placeholder | from yaml
    let val = $pls | columns
    | zip ($args | range 1..)
    | reduce -f {} {|i,a|
        $a | insert ($i.0 | into string) ($pls | get $i.0 | get $i.1)
    }

    let prompt = $role.template | render {_: $placehold, ...$val}
    let system = if ($role.system | is-not-empty) {
        $role.system | render $val
    }

    $input | (ai-send -p $placehold
        --system $system --function=$function
        --tag tool --forget
        --out=$out --debug=$debug
        -m $model $prompt)
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
