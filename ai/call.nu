use sqlite.nu *
use common.nu *
use function.nu *
use completion.nu *
use base.nu *
use data.nu
export use config.nu *

export-env {
    $env.AI_SESSION = date now | format date '%y%m%d%H%M%S'
    data init
    data make-session $env.AI_SESSION
}

export def ai-send [
    message: string = '{}'
    --session(-s): record
    --system: string
    --function(-f): list<string@cmpl-tools>
    --prevent-func
    --tools(-t): list<string@cmpl-nu-function>
    --image(-i): path
    --oneshot
    --placehold: string = '{}'
    --limit: int = 20
    --out(-o)
    --tag: string = ''
    --debug
] {
    let content = $in | default ""
    let content = $message | str replace --all $placehold $content
    let s = $session
    mut req = ai-req $s -m $s.model -t $s.temperature
    if ($system | is-not-empty) {
        $req = $req | ai-req $s -r system $system
    }
    if $oneshot {
        $req = $req | ai-req $s -r user -i $image $content
    } else {
        $req = data messages $limit
        | reduce -f $req {|i, a|
            # TODO: tools
            $a | ai-req $s -r $i.role $i.content
        }
        | ai-req $s -r user $content
    }

    mut fn_list = []
    let fns = if ($tools | is-not-empty) {
        # TODO: delete
        $fn_list = func-list ...$tools
        $fn_list | select type function
    } else if ($function | is-not-empty) {
        closure-list $function
    }
    $req = $req | ai-req $s -f $fns

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
                if $prevent_func { return $r }
                $req = $req | ai-req $s -r assistant $r.msg --tool-calls $r.tools
                let rt = closure-run $r.tools
                for x in $rt {
                    $req = $req
                    | ai-req $s -r tool ($x.result | to json -r) --tool-call-id $x.id
                }
                if $debug { print $"(ansi blue)($req | to yaml)(ansi reset)" }
                # TODO: 0 or 1?
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

export def --env ai-assistant [
    --provider(-p): string@cmpl-provider
    --model(-m): string@cmpl-models
    --system: string@cmpl-system
    --out(-o)
    --debug
    ...message: string
] {
    let s = data session -p $provider -m $model
    let message = $message | str join ' '
    let system = if ($system | is-empty) {
        if 'AI_TOOLS_LIST' not-in $env {
            {AI_TOOLS_LIST: (data tools)} | load-env
        }
        let d = $env.AI_TOOLS_LIST
        $env.AI_CONFIG.assistant
        | str replace '{{templates}}' ($d.template | to yaml)
        | str replace '{{placeholders}}' ($d.placeholder | to yaml)
        | str replace '{{tools}}' ($d.function | to yaml)
    } else {
        sqlx $"select system from prompt where name = '($system)'"
        | get 0.system
    }
    let r = (
        ai-send -s $s
        --system $system
        --out=$out
        --debug=$debug
        --limit $env.AI_CONFIG.message_limit
        --function [router]
        --prevent-func
        $message
    )
    if ($r | describe) == string {
        return $r
    }
    if ($r.tools? | is-not-empty) {
        let a = $r | get -i tools.0.function.arguments | default '{}' | from json
        if ($a | is-empty) or ($a.template_name? | is-empty) or ($a.query? | is-empty) {
            print $"(ansi $env.AI_CONFIG.template_calls)Invalid template call(ansi reset)"
            print $"(ansi grey)($a | to yaml)(ansi reset)"
            return
        }
        print -e $"(ansi $env.AI_CONFIG.template_calls)[(date now | format date '%F %H:%M:%S')] ($a.template_name) ($a | reject template_name | to nuon)(ansi reset)"
        $a.query | ai-do $a.template_name ...$a.placeholders? -f $a.tools?
    }
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
    --prevent-func
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
    let pls = $pls | each { Q $in } | str join ', '
    let pls = sqlx $"select name, yaml from placeholder where name in \(($pls)\)"
    | reduce -f {} {|i,a|
        $a | upsert $i.name ($i.yaml | from yaml)
    }
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
        --prevent-func=$prevent_func
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
