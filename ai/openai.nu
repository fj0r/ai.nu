use sqlite.nu *
use common.nu *
use function.nu *
use completion.nu *
use data.nu
export use config.nu *

export-env {
    if 'OPENAI_SESSION' not-in $env {
        $env.OPENAI_SESSION = date now | format date '%FT%H:%M:%S.%f'
    }
    data init
    data make-session $env.OPENAI_SESSION
}

def request [
    session
    req
    --out
] {
    let r = if $env.OPENAI_CONFIG.curl {
        $req | to json -r | curl -sSL -H 'Content-Type: application/json' -H $"Authorization: Bearer ($session.api_key)"  $"($session.baseurl)/chat/completions" --data @-
    } else {
        http post -e -t application/json --headers [Authorization $"Bearer ($session.api_key)"] $"($session.baseurl)/chat/completions" $req
    }
    | lines
    | reduce -f {msg: '', token: 0, tools: []} {|i,a|
        let x = $i | parse -r '.*?(?<data>\{.*)'
        if ($x | is-empty) { return $a }
        let x = $x | get 0.data | from json

        if 'error' in $x {
            error make {
                msg: ($x.error | to yaml)
            }
        }

        let tools = $x.choices
        | each {|i|
            if 'tool_calls' in $i.delta { [$i.delta.tool_calls] } else { [] }
        }
        | flatten
        | flatten

        let m = $x.choices
        | each {
            let i = $in
            let s = $i.delta.content? | default ''
            if not $out { print -n $s }
            if ($env.OPENAI_CONFIG.finish_reason | is-not-empty) and ($i.finish_reason? | is-not-empty) {
                print -e $"(ansi $env.OPENAI_CONFIG.finish_reason)<($i.finish_reason)>(ansi reset)"
            }
            $s
        }
        | str join

        $a
        | update msg {|x| $x.msg + $m }
        | update tools {|x| $x.tools | append $tools }
        | update token {|x| $x.token + 1 }
    }
    let tools = if ($r.tools | is-empty) {
        []
    } else {
        $r.tools
        | each {|x|
            let v = $x
            | upsert id {|y| [($y.id? | default '')] }
            | upsert function.name {|y| [($y.function?.name? | default '')] }
            | upsert function.arguments {|y|
                [($y.function?.arguments? | default '')]
            }
            let k = $x.index? | default 0
            {$k: $v}
        }
        | reduce {|i,a|
            $a | merge deep $i --strategy=append
        }
        | items {|k, v| $v }
        | update id {|y| $y.id | str join }
        | update function.name {|y| $y.function.name | str join }
        | update function.arguments {|y| $y.function.arguments | str join }
    }
    $r | update tools $tools
}

export def ai-send [
    message: string = '{}'
    --session(-s): record
    --system: string
    --function(-f): list<string@cmpl-tools>
    --prevent-call
    --tools(-t): list<string@cmpl-nu-function>
    --image(-i): path
    --oneshot
    --placehold: string = '{}'
    --out(-o)
    --tag: string = ''
    --debug
] {
    let content = $in | default ""
    let content = $message | str replace --all $placehold $content
    let s = $session
    data record $s.created $s.provider $s.model 'user' $content 0 $tag
    let sys = if ($system | is-empty) { [] } else { [{role: "system", content: $system}] }
    let user = if $oneshot {
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

    mut fn_list = []
    let fns = if ($tools | is-not-empty) {
        $fn_list = func-list ...$tools
        { tools: ($fn_list | select type function), tool_choice: auto }
    } else if ($function | is-not-empty) {
        { tools: (closure-list $function), tool_choice: auto }
    } else {
        {}
    }
    let req = {
        model: $s.model
        messages: [...$sys ...$user]
        temperature: $s.temperature
        stream: true
        ...$fns
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
    let r = request $s $req --out=$out
    data record $s.created $s.provider $s.model 'assistant' $r.msg $r.token $tag
    if ($fns | is-not-empty) {
        if ($tools | is-empty) {
            mut r0 = $r
            mut msg = $req.messages
            mut rst = []
            while ($r0.tools | is-not-empty) {
                let r1 = closure-run $r0.tools
                data record $s.created $s.provider $s.model 'tool_calls' ($r1 | to yaml) $r.token $tag
                if $prevent_call { return $r1 }
                let r1 = $r1 | each {|x|
                    {role: 'tool', content: ($x.result | to json -r), tool_call_id: $x.id}
                }
                let h1 = {role: 'assistant', content: $r0.msg, tool_calls: $r0.tools}
                $msg ++= [$h1 ...$r1]
                let req = $req | update messages $msg
                if $debug { print ($req | table -e) }
                let r2 = request $s $req --out=$out
                data record $s.created $s.provider $s.model 'assistant' $r2.msg $r0.token $tag
                $rst ++= [$r2.msg]
                $r0 = $r2
            }
            if $out { return $rst }
        } else {
            return (json-to-func $r.tools $fn_list)
        }
    }
    if $out { return $r.msg }
}

export def ai-chat [
    --provider(-p): string@cmpl-provider
    --model(-m): string@cmpl-models
    --system: string@cmpl-system
] {
    let s = data session -p $provider -m $model
    let system = if ($system | is-empty) { '' } else {
        sqlx $"select system from prompt where name = '($system)'"
        | get 0.system
    }
    let p = $'😎 '
    let ci = ansi grey
    let cr = ansi reset
    let cm = ansi yellow
    let nl = char newline
    mut model = $s.model
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
                ai-send -s $s --system $system $a
                print $cr
            }
        }
    }
}

export def ai-editor-run [--debug] {
    let ctx = $env.AI_EDITOR_CONTEXT | from nuon
    if $ctx.action == 'ai-do' {
        let c = open -r $ctx.file
        if ($c | is-empty) {
            print -e $"(ansi grey)no content, ignore(ansi reset)"
        } else {
            $c | ai-do ...$ctx.args --provider $ctx.provider? --model $ctx.model --function $ctx.function --image $ctx.image --debug=$debug
        }
    }
}

export def ai-do [
    ...args: string@cmpl-role
    --out(-o)
    --provider: string@cmpl-provider
    --model: string@cmpl-models
    --function(-f): list<string@cmpl-tools>
    --prevent-call
    --tools(-t): list<string@cmpl-nu-function>
    --image(-i): path
    --previous(-p): int@cmpl-previous
    --debug
] {
    let input = $in
    let s = data session -p $provider -m $model
    let input = if ($input | is-empty) {
        if ($previous | is-not-empty) {
            sqlx $"select content from scratch where id = ($previous)" | get 0.content
        } else {
            ''
        }
        | block-edit $"($args | str join '_').XXX.temp" --context {
            action: ai-do
            args: $args
            provider: $s.provider
            model: $s.model
            function: $function
            image: $image
        }
        | tee {
            sqlx $"insert into scratch \(type, args, content, model\) values \('ai-do', (Q ($args | str join ' ')), (Q $in), (Q $s.model)\)"
        }
    } else {
        $input
    }
    let role = sqlx $"select * from prompt where name = '($args.0)'" | first
    let fns = sqlx $"select tool from prompt_tools where prompt = '($args.0)'"
    | get tool
    | append $function

    let placehold = $"<(random chars -l 6)>"

    let pls = $role.placeholder | from yaml
    let val = $pls | columns
    | zip ($args | slice 1..)
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
        ai-send
        --session $s
        --placehold $placehold
        --system $system
        --function $fns
        --prevent-call=$prevent_call
        --tools $tools
        --image $image
        --tag ($args | str join ',')
        --oneshot
        --out=$out
        --debug=$debug
        $prompt
    )
}

export def ai-embed [
    input: string
    --provider: string@cmpl-provider
    --model: string@cmpl-models
] {
    let s = data session -p $provider -m $model
    http post -t application/json $"($s.baseurl)/embeddings" {
        model: $s.model, input: [$input], encoding_format: 'float'
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
