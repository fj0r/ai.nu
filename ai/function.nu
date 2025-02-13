export-env {
    $env.AI_TOOLS = {}
}

export def closure-list [list] {
    let list = $list
    | reduce -f {name: [], defs: []} {|i,a|
        let p = if ($i | describe) == string { 'name' } else { 'defs' }
        $a | update $p {|x| $a | get $p | append $i}
    }
    $list.name
    | uniq
    | each {|x|
        let a = $env.AI_TOOLS | get $x
        | get schema
        | upsert parameters.properties {|y|
            $y.parameters.properties
            | transpose k v
            | reduce -f {} {|i,a|
                let v = if ('enum' in $i.v) and ($i.v.enum | describe -d).type == 'closure' {
                    let c = $env.AI_TOOLS | get -i $x | get -i context
                    let c = if ($c | describe -d).type == 'closure' { do $c } else { $c } | default {}
                    $i.v | upsert enum (do $i.v.enum $c)
                } else {
                    $i.v
                }
                $a | insert $i.k $v
            }
        }
        {type: function, function: $a}
    }
    | append $list.defs
}

export def ConfirmExec [msg cond act alt] {
    print $"(ansi yellow)($msg)(ansi reset)"
    if $cond and ([yes no] | input list 'confirm') == 'no' {
        do $alt
        return 'canceled'
    } else {
        do $act
        return 'success'
    }
}

export def AiSend [session tag system=''] {
    $in | ai-send $session --system $system --oneshot --tag $tag
}

export def closure-run [list] {
    $list
    | par-each {|x|
        let name = $x.function.name
        let f = $env.AI_TOOLS | get -i $name
        let c = $f.context?
        let c = if ($c | describe -d).type == 'closure' { do $c } else { $c } | default {}
        if ($f | is-empty) { return $"Err: function ($x.function.name) not found" }
        let f = $f.handler
        let a = $x.function.arguments | from json

        if ($env.AI_CONFIG.tool_calls | is-not-empty) {
            print -e $"(ansi $env.AI_CONFIG.tool_calls)[(date now | format date '%F %H:%M:%S')] ($name) ($a | to nuon)(ansi reset)"
        }
        let c = $c | merge {
            AiSend: {|session tag system| $in | AiSend $session $tag $system}
            ConfirmExec: {|m d a| ConfirmExec $m $d $in $a }
        }
        $x | insert result (do $f $a $c)
    }
}

