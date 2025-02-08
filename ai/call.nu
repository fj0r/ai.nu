use sqlite.nu *
use common.nu *
use function.nu *
use completion.nu *
use base.nu *
use data.nu
export use config.nu *

export-env {
    $env.OPENAI_SESSION = date now | format date '%FT%H:%M:%S.%f'
    data init
    data make-session $env.OPENAI_SESSION
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
    mut req = ai-req -m $s.model -t $s.temperature
    if ($system | is-not-empty) {
        $req = $req | ai-req -r system $system
    }
    if $oneshot {
        $req = $req | ai-req -r user -i $image $content
    } else {
        $req = data messages
        | reduce -f $req {|i, a|
            $a | ai-req -r $i.role $i.content
        }
        | ai-req -r user $content
    }

    mut fn_list = []
    let fns = if ($tools | is-not-empty) {
        # TODO: delete
        $fn_list = func-list ...$tools
        $fn_list | select type function
    } else if ($function | is-not-empty) {
        closure-list $function
    }
    $req = $req | ai-req -f $fns

    if $debug {
        let xxx = [
            '' 'message' $message
            'placeholder' $placehold
            'content' $content
        ] | str join "\n------\n"
        print $"(ansi blue)($xxx)(ansi reset)"
        print $"======req======"
        print $"(ansi blue)($req | to yaml)(ansi reset)"
    }
    let r = $req | ai-call $s --out=$out --tag $tag
    if ($fns | is-not-empty) {
        if ($tools | is-empty) {
            mut r = $r
            mut msg = $req.messages
            mut rst = []
            while ($r.tools | is-not-empty) {
                $req = $req | ai-req -r assistant $r.msg --tool-calls $r.tools
                let rt = closure-run $r.tools
                if $prevent_call { return $rt }
                for x in $rt {
                    $req = $req
                    | ai-req -r tool ($x.result | to json -r) --tool-call-id $x.id
                }
                if $debug { print $"(ansi blue)($req | to yaml)(ansi reset)" }
                # 0 or 1?
                $r = $req | ai-call $s --out=$out --tag $tag --record (($rt | length) + 0)
                $rst ++= [$r.msg]
            }
            if $out { return $rst }
        } else {
            return (json-to-func $r.tools $fn_list)
        }
    }
    if $out { return $r.msg }
}

export def ai-assistant [
    --provider(-p): string@cmpl-provider
    --model(-m): string@cmpl-models
    --system: string@cmpl-system
    --debug
    ...message: string
] {
    let s = data session -p $provider -m $model
    let system = if ($system | is-empty) { '' } else {
        sqlx $"select system from prompt where name = '($system)'"
        | get 0.system
    }
    ai-send -s $s --system $system --debug=$debug ($message | str join ' ')
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
