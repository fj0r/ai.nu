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
        let c = $env.AI_TOOLS | get -i $x | get -i context
        let c = if ($c | describe -d).type == 'closure' { do $c } else { $c } | default {}
        let a = $env.AI_TOOLS | get $x
        | get schema
        | upsert parameters.properties {|y|
            $y.parameters.properties
            | transpose k v
            | reduce -f {} {|i,a|
                [enum description] | reduce -f $a {|j,b|
                    let v = if ($j in $i.v) and ($i.v | get $j | describe -d).type == 'closure' {
                        $i.v | upsert $j (do ($i.v | get $j) $c)
                    } else {
                        $i.v
                    }
                    $b | upsert $i.k $v
                }
            }
        }
        | upsert description {|x|
            if ($x.description | describe -d).type == 'closure' {
                do $x.description $c
            } else {
                $x.description
            }
        }
        {type: function, function: $a}
    }
    | append $list.defs
}

export def ConfirmExec [msg cond act alt] {
    print $"(ansi yellow)($msg)(ansi reset)"
    if $cond and ([yes no] | input list 'confirm') == 'no' {
        let r = do $alt
        return $'### CANCELED\n($r)'
    } else {
        let r = do $act
        return $'### SUCCESS\n($r)'
    }
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
            AiSend: {|session system|
                $in | ai-send $session --system $system --oneshot --tag $"[($name)]($a)"
            }
            ConfirmExec: {|m d a| ConfirmExec $m $d $in $a }
        }
        $x | insert result (do $f $a $c)
    }
}

export def prompts-call [rep c] {
    let a = $rep | get -i result.tools.0.function.arguments | default '{}' | from json
    let tc_id = $rep.result.tools.0.id
    let s = $c.selector
    let snv = $a | get -i $s.prompt
    let inv = $a | get -i $s.message
    let onv = $a | get -i $s.placeholder
    let tlv = $a | get -i $s.tools
    let tc_color = ansi $env.AI_CONFIG.template_calls
    let rs_color = ansi reset
    if ([$a $snv $inv $snv] | any {|i| $i | is-empty} ) {
        return {
            err: $"($env.AI_CONFIG.assistant.function.name) missing args\n\n($a | to yaml)"
            tools_id: $tc_id
        }
    } else if $snv not-in $c.prompt.name {
        return  {
            err: $"($snv) not a valid ($s.prompt)"
            tools_id: $tc_id
        }
    }
    print -e $"($tc_color)[(date now | format date '%F %H:%M:%S')] ($snv) ($a | reject $s.prompt | to nuon)($rs_color)"
    let o = $onv | default {}
    let o = if ($o | describe) == 'string' { $o | from json } else { $o }
    let pls = $c.prompt | where name == $snv | get 0.placeholder
    let pls = $pls | each {|x|
        let y = $o | get -i $x
        if ($y | is-empty) {
            let e = $c.placeholder | where name == $x | get 0.enum
            $e | columns | input list $"($tc_color)Choose a value for (ansi xterm_yellow)($x)($rs_color)"
        } else {
            $y
        }
    } | default []
    let x = $inv | ai-do $snv ...$pls -f $tlv -o
    {
        result: $x
        tools_id: $tc_id
    }
}
