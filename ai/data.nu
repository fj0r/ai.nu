use sqlite.nu *

export def --env init [] {
    let db = [$nu.data-dir 'openai.db'] | path join
    $env.OPENAI_DB = $db
    if ($env.OPENAI_DB | path exists) { return }
    {_: '.'} | into sqlite -t _ $env.OPENAI_DB
    print $"(ansi grey)created database: $env.OPENAI_DB(ansi reset)"
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
            placeholder TEXT,
            description TEXT
        );"
        "CREATE INDEX idx_prompt ON prompt (name);"
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

        "INSERT INTO provider (name, baseurl, model_default, temp_max, active) VALUES ('ollama', 'http://localhost:11434/v1', 'llama3.2:latest', 1, 1);"

        "INSERT INTO prompt (name, system, template, placeholder, description) VALUES
        ('json-to', '', 'Analyze the following JSON data to convert it into a {} {}.\nDo not explain.\n```\n{}\n```', '[{\"jsonschema\":\"JsonSchema\",\"rs\":\"Rust\",\"hs\":\"Haskell\",\"ts\":\"TypeScript\",\"py\":\"Python pydantic\",\"nu\":\"Nushell\",\"psql\":\"PostgreSQL\",\"mysql\":\"MySQL\",\"slite\":\"Sqlite\"},{\"type\":\"Type\",\"struct\":\"Struct\",\"class\":\"Class\",\"trait\":\"Trait\",\"interface\":\"Interface\",\"table\":\"Table\"}]', 'Analyze JSON content, converting it into'),
        ('git-diff-summary', '', 'Extract commit logs from git differences, summarizing only the content changes in files while ignoring hash changes, and generate a title.\n```\n{}\n```', '', 'Summarize from git differences'),
        ('api-doc', '', '{} Inquire about the usage of the API and provide an example.\n```\n{}\n```', '[{\"rust\":\"You are a Rust language expert.\",\"javascript\":\"You are a Javascript language expert.\",\"python\":\"You are a Python language expert.\",\"nushell\":\"You are a Nushell language expert.\",\"sql\":\"You are a Database expert.\"}]', ''),
        ('debug', '', '{} Analyze the causes of the error and provide suggestions for correction.\n```\n{}\n```', '[{\"rust\":\"You are a Rust language expert.\",\"javascript\":\"You are a Javascript language expert.\",\"python\":\"You are a Python language expert.\",\"nushell\":\"You are a Nushell language expert.\"}]', 'Programming language experts help you debug.'),
        ('dictionary', '', 'Explain the meaning, usage, list synonyms and antonyms of the following words:\n```{}```', '', 'dictionary'),
        ('dictionary-zh', '', '解释以下单词含义，用法，并列出同义词，近义词和反义词:\n```{}```', '', 'dictionary'),
        ('synonyms', '', '解释以下词语的区别，并介绍相关的近义词和反义词\n```{}```', '', '近义词解析'),
        ('trans-to', '', 'Translate the following text into {}:\n```\n{}\n```', '[{\"en\":\"English\",\"zh\":\"Chinese\"}]', 'Translation into the specified language');"
    ] {
        open $env.OPENAI_DB | query db $s
    }
}

export def make-session [created] {
    for s in [
        $"INSERT INTO sessions \(created, provider, model, temperature\)
        SELECT (Q $created), name, model_default, temp_default
        FROM provider where active = 1 limit 1;"
    ] {
        open $env.OPENAI_DB | query db $s
    }
}

export def edit [table pk] {
    open $env.OPENAI_DB
    | query db $"select * from ($table) where name = (Q $pk)"
    | first
    | to yaml
    | $"### config ($table)#($pk) \n($in)"
    | block-edit $"config-($table).XXX.yml"
    | from yaml
    | db-upsert $env.OPENAI_DB $table name
}

export def query [s] {
    #print $s
    let r = open $env.OPENAI_DB | query db $s
    if ($r | length) > 0 {
        $r | first
    } else {
        {}
    }
}

export def session [] {
    query $"select * from provider as p join sessions as s
        on p.name = s.provider where s.created = (Q $env.OPENAI_SESSION);"
}

export def record [session, provider, model, role, content, token, tag] {
    let n = date now | format date '%FT%H:%M:%S.%f'
    query $"insert into messages \(session_id, provider, model, role, content, token, created, tag\)
        VALUES \((Q $session), (Q $provider), (Q $model), (Q $role), (Q $content), (Q $token), (Q $n), (Q $tag)\);"
}

export def messages [num = 10] {
    open $env.OPENAI_DB
    | query db $"select role, content from messages where session_id = (Q $env.OPENAI_SESSION) and tag = '' limit ($num)"
}