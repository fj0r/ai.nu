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
        filter: {
            out: {
                placeholder: { $in | to yaml }
            }
            in: {
                placeholder: { $in | from yaml }
            }
        }
    }
}

export def seed [dir?:path] {
    let dir = if ($dir | is-empty) {
        [$env.FILE_PWD data] | path join
    } else {
        $dir
    }

    ls ([$dir prompts] | path join)  | get name | each { open $in | upsert-prompt }
}

export def --env init [] {
    init-db OPENAI_STATE ([$nu.data-dir 'openai.db'] | path join) {|sqlx, Q|
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
                created TEXT,
                provider TEXT NOT NULL,
                model TEXT NOT NULL,
                temperature REAL NOT NULL
            );"
            "CREATE INDEX idx_sessions ON sessions (created);"
            "CREATE TABLE IF NOT EXISTS prompt (
                name TEXT PRIMARY KEY,
                system TEXT,
                template TEXT,
                placeholder TEXT NOT NULL DEFAULT '{}',
                description TEXT
            );"
            "CREATE INDEX idx_prompt ON prompt (name);"
            "CREATE TABLE IF NOT EXISTS prompt_tools (
                prompt TEXT,
                tool TEXT,
                type TEXT DEFAULT 'function',
                PRIMARY KEY (prompt, tool)
            );"
            "CREATE TABLE IF NOT EXISTS messages (
                session_id TEXT,
                provider TEXT,
                model TEXT,
                role TEXT,
                content TEXT,
                token INTEGER,
                created TEXT,
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

export def make-session [created] {
    for s in [
        $"INSERT INTO sessions \(created, provider, model, temperature\)
        SELECT (Q $created), name, model_default, temp_default
        FROM provider where active = 1 limit 1;"
    ] {
        sqlx $s
    }
}

export def session [-p:string -m:string] {
    mut o = sqlx $"select * from provider as p join sessions as s
        on p.name = s.provider where s.created = (Q $env.OPENAI_SESSION);" | first
    if ($p | is-not-empty) {
        let p = sqlx $"select * from provider where name = (Q $p)" | first
        $o = $o | merge $p
    }
    if ($m | is-not-empty) { $o.model = $m }
    $o
}

export def record [ctx, role, content, token, tag] {
    let n = date now | format date '%FT%H:%M:%S.%f'
    let session = $ctx.created
    let provider = $ctx.provider
    let model = $ctx.model
    sqlx $"insert into messages \(session_id, provider, model, role, content, token, created, tag\)
        VALUES \((Q $session), (Q $provider), (Q $model), (Q $role), (Q $content), (Q $token), (Q $n), (Q $tag)\);"
}

export def messages [num = 10] {
    sqlx $"select role, content from messages where session_id = (Q $env.OPENAI_SESSION) and tag = '' order by created desc limit ($num)"
    | reverse
}
