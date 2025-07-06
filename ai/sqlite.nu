export def Q [...t --sep:string=''] {
    let s = $t | str join $sep | str replace -a "'" "''"
    $"'($s)'"
}

export def sqlx [s] {
    open $env.AI_STATE | query db $s
}

export def --env init-db [env_name:string, file:string, hook: closure] {
    let begin = date now
    if $env_name not-in $env {
        {$env_name: $file} | load-env
    }
    if ($file | path exists) { return }
    mkdir ($file | path parse | get parent)
    {_: '.'} | into sqlite -t _ $file
    open $file | query db "DROP TABLE _;"
    do $hook {|s| open $file | query db $s } {|...t| Q ...$t }
    print $"(ansi grey)created database: $env.($env_name), takes ((date now) - $begin)(ansi reset)"
}

export def db-upsert [table pk --do-nothing] {
    let r = $in
    let d = if $do_nothing { 'NOTHING' } else {
        let u = $r | columns | each {|x| $"($x) = EXCLUDED.($x)" } | str join ', '
        $"UPDATE SET ($u)"
    }
    sqlx $"
        INSERT INTO ($table)\(($r | columns | str join ',')\)
        VALUES\(($r | values | each {Q $in} | str join ',')\)
        ON CONFLICT\(($pk | str join ', ')\) DO ($d);"
}

export def table-merge [
    config
    --action: closure
] {
    let d = $in
    let d = $config.default | merge $d
    let d = if ($action | is-not-empty) {
        $d | do $action $config
    } else {
        $d
    }
    $d | select ...($config.default | columns)
}

export def table-upsert [
    config
    --delete
    --action: closure
] {
    let r = $in
    | table-merge $config --action $action
    if $delete {
        let pks = $config.default
        | columns
        | reduce -f {} {|i,a|
            if $i in $config.pk {
                $a | insert $i ($r | get $i)
            } else {
                $a
            }
        }
        | items {|k,v|
            $"($k) = (Q $v)"
        }
        | str join ' and '
        sqlx $"delete from ($config.table) where ($pks)"
    } else {
        $r | db-upsert $config.table $config.pk
    }
}

export def insert-prompt-tools [] {
    $in
    | transpose k v
    | each {|x|
        let v = $x.v | each { $"\((Q $x.k), (Q $in)\)" } | str join ', '
        sqlx $"insert or replace into prompt_tools \(prompt, tool\) values ($v);"
    }
}
