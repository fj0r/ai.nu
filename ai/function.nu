export-env {
    $env.AI_TOOLS = {}
}

export def closure-list [list] {
    $list
    | uniq
    | each {|x|
        let a = $env.AI_TOOLS | get $x
        | get schema
        | upsert parameters.properties {|y|
            $y.parameters.properties
            | transpose k v
            | reduce -f {} {|i,a|
                let v = if ('enum' in $i.v) and ($i.v.enum | describe -d).type == 'closure' {
                    let c = $env.AI_TOOLS | get -i $x | get -i config
                    let c = if ($c | describe -d).type == 'closure' { do $c } else { $c } | default {}
                    $i.v | upsert enum (do $i.v.enum $c)
                } else {
                    $i.v
                }
                $a | insert $i.k $v
            }
        }
        {type: function, function: ($a | upsert name $x)}
    }
}

export def closure-run [list] {
    $list
    | par-each {|x|
        let name = $x.function.name
        let f = $env.AI_TOOLS | get -i $name
        let c = $f.config?
        let c = if ($c | describe -d).type == 'closure' { do $c } else { $c } | default {}
        if ($f | is-empty) { return $"Err: function ($x.function.name) not found" }
        let f = $f.handler
        let a = $x.function.arguments | from json

        if ($env.AI_CONFIG.tool_calls | is-not-empty) {
            print -e $"(ansi $env.AI_CONFIG.tool_calls)[(date now | format date '%F %H:%M:%S')] ($name) ($a | to nuon)(ansi reset)"
        }
        $x | insert result (do $f $a $c)
    }
}

