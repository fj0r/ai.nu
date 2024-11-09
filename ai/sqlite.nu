export def Q [...t --sep:string=''] {
    let s = $t | str join $sep | str replace -a "'" "''"
    $"'($s)'"
}

export def run [s] {
    open $env.OPENAI_DB | query db $s
}

export def --env init-db [env_name:string, file:string, hook: closure] {
    let begin = date now
    if $env_name not-in $env {
        {$env_name: $file} | load-env
    }
    if ($file | path exists) { return }
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
    run $"
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
    let fi = $config.filter?.in?
    let d = if ($fi | is-empty) {
        $d
    } else {
        $config.default
        | columns
        | reduce -f {} {|i,a|
            let x = $d | get $i
            let x = if ($i in $fi) {
                $x | do ($fi | get $i) $x
            } else {
                $x
            }
            $a | insert $i $x
        }
    }
    let d = if ($action | is-not-empty) {
        $d | do $action $config
    } else {
        $d
    }
    let fo = $config.filter?.out? | default {}
    $config.default
    | columns
    | reduce -f {} {|i,a|
        let x = $d | get $i
        let x = if ($i in $fo) {
            $x | do ($fo | get $i) $x
        } else {
            $x
        }
        $a | insert $i $x
    }
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
        run $"delete from ($config.table) where ($pks)"
    } else {
        $r | db-upsert $config.table $config.pk
    }
}

