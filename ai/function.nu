export-env {
    $env.OPENAI_TOOLS = {
        get_weather: {
            schema: {
                description: 'Get the current weather in a given location'
                parameters: {
                    type: object
                    properties: {
                        location: {
                          type: string
                          description: "The city and state, e.g. San Francisco, CA"
                        },
                        unit: {
                          type: string
                          enum: {|| [celsius fahrenheit] }
                        }
                    }
                    required: [location]
                }
            }
            handler: {|x, config|
                let location = $x.location
                let unit = $x.unit
                {
                    observation_time: "12:35 PM"
                    unit: $x.unit
                    temparature: 16
                    wind_speed: 17
                    wind_dir: "W"
                    pressure: 1016
                    humidity: 87
                    cloudcover: 100
                    feelslike: 16
                    visibility: 16
                }
            }
        }
        search_web: {
            schema: {
                description: 'This function allows you to perform a search using search engine. It can be used to find web pages, images, videos, or any other content based on provided keywords.'
                parameters: {
                    type: object
                    properties: {
                        query: {
                          type: string
                          description: "The search terms or keywords"
                        }
                        num_results: {
                          type: number
                          description: "The number of results to return"
                        }
                        language: {
                          type: string
                          description: "The language of the search results"
                        }
                        search_type: {
                          type: string
                          description: "The type of search"
                          enum: [web image video]
                        }
                    }
                    required: [query]
                }
            }
            handler: {|x, config|
                return 'hello'
            }
        }
    }
}

export def closure-list [list] {
    $list
    | uniq
    | each {|x|
        let a = $env.OPENAI_TOOLS | get $x
        | get schema
        | upsert parameters.properties {|y|
            $y.parameters.properties
            | transpose k v
            | reduce -f {} {|i,a|
                let v = if ('enum' in $i.v) and ($i.v.enum | describe -d).type == 'closure' {
                    $i.v | upsert enum (do $i.v.enum)
                } else {
                    $i.v
                }
                $a | insert $i.k $v
            }
        }
        {type: function, function: {name: $x, ...$a}}
    }
}

export def closure-run [list] {
    $list
    | each {|x|
        let f = $env.OPENAI_TOOLS | get -i $x.function.name
        if ($f | is-empty) { return $"Err: function ($x.function.name) not found" }
        let f = $f.handler
        let a = $x.function.arguments | from json
        $x | insert result (do $f $a {})
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
