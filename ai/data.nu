use sqlite.nu *

export def upsert-provider [--delete --action: closure] {
    $in | table-upsert --delete=$delete --action $action {
        table: provider
        pk: [name]
        default: {
            name: ''
            baseurl: 'https://'
            api_key: ''
            model_default: ''
            temp_default: 0.5
            temp_min: 0.0
            temp_max: 1.0
            org_id: ''
            project_id: ''
            active: 0
        }
    }
}

export def upsert-prompt [--delete --action: closure] {
    $in | table-upsert --action $action --delete=$delete {
        table: prompt
        pk: [name]
        default: {
            name: ''
            system: ''
            template: "```\n{{}}\n```"
            placeholder: '{}'
            description: ''
        }
    }
}


export def seed [] {
    const dir = path self .

    ls ([$dir data prompts] | path join)  | get name | each { open $in | upsert-prompt }
    ls ([$dir data placeholder] | path join)  | get name | each {
        open $in | table-upsert {
            table: placeholder
            pk: [name]
            default: {
                name: ''
                yaml: ''
            }
        }
    }
}

export def --env init [] {
    init-db AI_STATE ([$nu.data-dir 'openai.db'] | path join) {|sqlx, Q|
        for s in [
            "CREATE TABLE IF NOT EXISTS provider (
                name TEXT PRIMARY KEY,
                baseurl TEXT NOT NULL,
                api_key TEXT DEFAULT '',
                model_default TEXT DEFAULT 'qwen2:1.5b',
                temp_default REAL DEFAULT 0.5,
                temp_min REAL DEFAULT 0,
                temp_max REAL NOT NULL,
                org_id TEXT DEFAULT '',
                project_id TEXT DEFAULT '',
                adapter TEXT DEFAULT 'openai',
                active BOOLEAN DEFAULT 0
            );"
            "CREATE INDEX idx_provider ON provider (name);"
            "CREATE INDEX idx_active ON provider (active);"
            "CREATE TABLE IF NOT EXISTS sessions (
                id INTEGER PRIMARY KEY,
                parent_id INTEGER DEFAULT -1,
                offset INTEGER DEFAULT -1,
                created TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%f','now')),
                provider TEXT NOT NULL,
                model TEXT NOT NULL,
                temperature REAL NOT NULL
            );"
            "CREATE INDEX idx_sessions_id ON sessions (id);"
            "CREATE INDEX idx_sessions_pid ON sessions (parent_id);"
            "CREATE TABLE IF NOT EXISTS prompt (
                name TEXT PRIMARY KEY,
                system TEXT,
                template TEXT,
                placeholder TEXT NOT NULL DEFAULT '[]',
                description TEXT
            );"
            "CREATE INDEX idx_prompt ON prompt (name);"
            "CREATE TABLE IF NOT EXISTS placeholder (
                name TEXT PRIMARY KEY,
                yaml TEXT NOT NULL DEFAULT '{}'
            );"
            "CREATE INDEX idx_placeholder ON placeholder (name);"
            "CREATE TABLE IF NOT EXISTS prompt_tools (
                prompt TEXT,
                tool TEXT,
                type TEXT DEFAULT 'function',
                PRIMARY KEY (prompt, tool)
            );"
            "CREATE TABLE IF NOT EXISTS messages (
                session_id INTEGER REFERENCES sessions(id),
                provider TEXT,
                model TEXT,
                role TEXT,
                content TEXT,
                tool_calls TEXT,
                token INTEGER,
                created TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%f','now')),
                tag TEXT
            );"
            "CREATE INDEX idx_messages ON messages (session_id);"

            "CREATE TABLE IF NOT EXISTS scratch (
                id INTEGER PRIMARY KEY,
                type TEXT DEFAULT '',
                args TEXT DEFAULT '',
                content TEXT DEFAULT '',
                created TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%S','now')),
                updated TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%S','now')),
                function TEXT '',
                model TEXT ''
            );"

            "INSERT INTO provider (name, baseurl, model_default, temp_max, active) VALUES ('ollama', 'http://localhost:11434/v1', 'llama3.2:latest', 1, 1);"
        ] {
            do $sqlx $s
        }
        seed
    }
}

export def make-session [] {
    sqlx "INSERT INTO sessions (provider, model, temperature)
        SELECT name, model_default, temp_default
        FROM provider where active = 1 limit 1 returning id;"
    | first
    | get id
}

export def session [-p:string -m:string] {
    mut o = sqlx $"select * from provider as p join sessions as s
        on p.name = s.provider where s.id = ($env.AI_SESSION);" | first
    if ($p | is-not-empty) {
        let p = sqlx $"select * from provider where name = (Q $p)" | first
        $o = $o | merge $p
    }
    if ($m | is-not-empty) { $o.model = $m }
    $o
}

export def record [
    ctx
    role
    content
    --tools: string = ''
    --token: int = 0
    --tag: string = ''
] {
    sqlx $"insert into messages \(session_id, provider, model, role, content, tool_calls, token, tag\)
        VALUES \(($ctx.id), (Q $ctx.provider), (Q $ctx.model), (Q $role), (Q $content), (Q $tools), (Q $token), (Q $tag)\);"
}

export def messages [
    num = 20
    --sql
] {
    let s = $"
    with recursive ss as \(
        select id, parent_id, offset, ($num) as os from sessions
        where id = ($env.AI_SESSION)
        union all
        select s.id, s.parent_id, s.offset, ss.offset as os from sessions as s
        join ss on ss.parent_id = s.id
    \), w as \(
        select ss.id as session_id, m.role, m.content, m.tool_calls, m.created,
            ss.os,
            rank\(\) over \(partition by ss.id order by m.created\) as rk
        from messages as m join ss on m.session_id = ss.id
        where m.tag = '' order by m.created desc
    \), r as materialized \(
        select session_id, role, content, tool_calls, created
        from w where os >= rk limit ($num)
    \) select * from r order by created
    "
    if $sql { return $s }
    # When the quantity exceeds the num, it will not be possible to obtain the subsequent data.
    # First retrieve the specified number in reverse order, and then reverse it.
    let o = sqlx $s
    # Clear unpaired `tool_calls` from the history
    mut c = 0
    mut r = []
    while $c < ($o | length) {
        let i = $o | get $c
        if ($i.tool_calls | is-not-empty) {
            # `get -i` for tail unpaired `tool_calls`
            let n = $o | get -i ($c + 1)
            if ($n.tool_calls? | is-not-empty) {
                $r ++= [$i $n]
            }
            $c += 1
        } else {
            $r ++= [$i]
        }
        $c += 1
    }
    $r
}

export def tools [] {
    mut t = $env.AI_PROMPTS | values
    for i in (sqlx $"select name, description, placeholder from prompt;") {
        if $i.name not-in $env.AI_PROMPTS {
            $t ++= [$i]
        }
    }
    let t = $t
    | update placeholder {|x|
        $x.placeholder | from yaml
    }

    let f = $env.AI_TOOLS | items {|k, v|
        {name: $k, description: ($v.schema.description?) }
    }

    let p = sqlx $"select name, yaml from placeholder;"
    | each {|x|
        {name: $x.name enum: ($x.yaml | from yaml)}
    }

    { template: $t, function: $f, placeholder: $p }
}

export def role [...args] {
    let role = if $args.0 in $env.AI_PROMPTS {
        $env.AI_PROMPTS | get $args.0
    } else {
        sqlx $"select * from prompt where name = '($args.0)'" | first
    }
    let pls = $role.placeholder | from yaml
    let plm = $pls | each { Q $in } | str join ', '
    let plm = sqlx $"select name, yaml from placeholder where name in \(($plm)\)"
    | reduce -f {} {|i,a|
        $a | upsert $i.name ($i.yaml | from yaml)
    }

    let val = $pls
    | enumerate
    | reduce -f {} {|i,a|
        let k = $args | get -i ($i.index + 1)
        let v = $plm | get $i.item | get -i ($k | default '')
        let v = if ($v | is-empty) {
            let v = $plm | get $i.item | values | str join '|'
            $"<choose:($v)>"
        } else {
            $v
        }

        $a
        | insert $"($i.item):" $i.item
        | insert $"($i.item)" $v
    }

    let system = if ($role.system | is-not-empty) {
        $role.system | render $val
    }
    {system: $system, vals: $val, template: $role.template}
}
