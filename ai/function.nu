export-env {
    $env.OPENAI_TOOLS = {
        get_weather: {
            schema: {
                description: 'Get the current weather in a given location'
                parameters: {
                    location: {
                      type: string
                      description: "The city and state, e.g. San Francisco, CA"
                    },
                    unit: {
                      type: string
                      enum: [celsius fahrenheit]
                    }
                }
                required: [location]
            }
            handler: {|x|
                let location = $x.location
                let unit = $x.unit
            }
        }
        search_web: {
            schema: {

            }
            handler: {|x|
            }
        }
    }
}


use completion.nu *

export def func-list [...fns:string@cmpl-nu-function] {
    scope commands
    | where name in $fns
    | each { func-to-json $in }
    | each {|x| {type: function, function: ($x | update parameters {|y| $y.parameters.value}), flags: $x.parameters.flags} }
}

export def func-to-json [fn] {
    $fn
    | insert parameters {|x|
        let x = $x.signatures | transpose k v | get 0.v
        mut p = {}
        mut r = []
        mut flags = []
        for i in $x {
            if ($i.parameter_name | is-empty) { continue }

            mut e = null
            let type = if ($i.syntax_shape? | default '' | str starts-with 'completable<') {
                $i.syntax_shape | str substring 12..<-1
                let e1 = nu -c $'do -i { ($i.custom_completion) } | to json' | from json 
                $e = if ($e1 | describe | str starts-with 'table') {
                    $e1 | get value
                } else {
                    $e1
                }
            } else if $i.parameter_type == 'switch' {
                'bool'
            } else {
                $i.syntax_shape
            }
            let e = if ($e | is-empty) { {} } else { {enum: $e} }

            if $i.parameter_type != positional {
                $flags ++= [$i.parameter_name]
            }

            if not $i.is_optional { $r ++= [$i.parameter_name] }

            $p = $p | insert $i.parameter_name {
                type: $type
                description: $i.description
                ...$e
            }
        }
        {
            value: {
                type: object
                properties: $p
                required: $r
            }
            flags: $flags
        }
    }
    | select name description parameters
}

export def json-to-func [o tools] {
    $o
    | each {|x|
        let f = $x.function
        let c = $tools | where function.name == $f.name | get -i 0.flags
        mut cmd = [$f.name]
        for i in ($f.arguments | from json | transpose k v) {
            let flag = if $i.k in $c { $"--($i.k)" } else { '' }
            if ($i.v | describe) == bool {
                if $i.v {
                    $cmd ++= [$flag]
                }
            } else {
                $cmd ++= [$flag $i.v]
            }
        }
        $cmd | str join ' '
    }
}
