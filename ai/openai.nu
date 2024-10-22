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
    message: string
    --model(-m): string@cmpl-models
    --system: string
    --function(-f): list<string@cmpl-function>
    --image(-i): path
    --forget(-f)
    --placehold(-p): string = '{}'
    --out(-o)
    --edit(-e)
    --temp(-t): string = 'send-message.XXX'
    --tag: string = ''
    --debug
] {
    let content = $in | default ""
    let content = if $edit {
        $content | block-edit $temp
    } else {
        $content
    }
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
    --debug
] {
    let input = $in
    let edit = $input | is-empty
    let s = data session
    let role = run $"select * from prompt where name = '($args.0)'" | first
    let placehold = $"<(random chars -l 6)>"
    let prompt = $role | get template | lines | each {|x|
        if ($x | str replace -ar "['\"`]+" '' | $in == '{}') {
            $x | str replace '{}' $placehold
        } else {
            $x
        }
    } | str join (char newline)
    let plc = $role.placeholder? | from json
    let prompt = $args | range 1.. | enumerate
    | reduce -f $prompt {|i,a|
        let x = ($plc | get $i.index) | get $i.item
        $a | str replace '{}' $x
    }
    | str replace --all '{}' ''

    $input | (ai-send -p $placehold
        --system $role.system? --function=$function
        --temp prompt-XXX --tag tool --forget
        --edit=$edit --out=$out --debug=$debug
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
