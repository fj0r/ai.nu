use sqlite.nu *

export def --env init [] {
    if 'OPENAI_DB' not-in $env {
        $env.OPENAI_DB = [$nu.data-dir 'openai.db'] | path join
    }
    if 'OPENAI_PROMPT_TEMPLATE' not-in $env {
        $env.OPENAI_PROMPT_TEMPLATE = "
            # Role:
            ## Background:
            ## Attention:
            ## Profile:
            ## Constraints:
            ## Goals:
            ## Skills:
            ## Workflow:
            ## OutputFormat:
            ## Suggestions:
            ## Initialization:
            " | lines | range 1..-1 | str substring 12.. | str join (char newline)
    }
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
        "CREATE TABLE IF NOT EXISTS function (
            name TEXT PRIMARY KEY,
            description TEXT,
            parameters TEXT,
            tag TEXT
        );"
        "CREATE INDEX idx_function ON function (name);"

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

        "INSERT INTO prompt (name, system, template, placeholder, description) VALUES
        ('json-to', '', 'Analyze the following JSON data to convert it into a {} {}.\nDo not explain.\n```\n{}\n```', '[{\"jsonschema\":\"JsonSchema\",\"rs\":\"Rust\",\"hs\":\"Haskell\",\"ts\":\"TypeScript\",\"py\":\"Python pydantic\",\"nu\":\"Nushell\",\"psql\":\"PostgreSQL\",\"mysql\":\"MySQL\",\"slite\":\"Sqlite\"},{\"type\":\"Type\",\"struct\":\"Struct\",\"class\":\"Class\",\"trait\":\"Trait\",\"interface\":\"Interface\",\"table\":\"Table\"}]', 'Analyze JSON content, converting it into'),
        ('git-diff-summary', '### Role\nYou are a git diff summary assistant.\n\n### Goals\nExtract commit messages from the `git diff` output\n\n## Constraints\nsummarize only the content changes within files, ignore changes in hashes, and generate a title based on these summaries.\n\n### Attention\n- Lines starting with `+` indicate new lines added.\n- Lines starting with `-` indicate deleted lines.\n- Other lines are context and are not part of the current change being described.', '```\n{}\n```', '', 'Summarize from git differences'),
        ('api-doc', '', '{} Inquire about the usage of the API and provide an example.\n```\n{}\n```', '[{\"rust\":\"You are a Rust language expert.\",\"javascript\":\"You are a Javascript language expert.\",\"python\":\"You are a Python language expert.\",\"nushell\":\"You are a Nushell language expert.\",\"sql\":\"You are a Database expert.\"}]', ''),
        ('debug', '', '{} Analyze the causes of the error and provide suggestions for correction.\n```\n{}\n```', '[{\"rust\":\"You are a Rust language expert.\",\"javascript\":\"You are a Javascript language expert.\",\"python\":\"You are a Python language expert.\",\"nushell\":\"You are a Nushell language expert.\"}]', 'Programming language experts help you debug.'),
        ('dictionary', '', 'Explain the meaning, usage, list synonyms and antonyms of the following words:\n```{}```', '', 'dictionary'),
        ('dictionary-zh', '', '解释以下单词含义，用法，并列出同义词，近义词和反义词:\n```{}```', '', 'dictionary'),
        ('synonyms', '', '解释以下词语的区别，并介绍相关的近义词和反义词\n```{}```', '', '近义词解析'),
        ('trans-to', '### Role\nYou are a translation assisant\n\n### Goals\nTranslate the following text into the specified language\n\n### Constraints\nOnly provide the translated content without explanations\nDo not enclose the translation result with quotes\n\n### Attention\nOther instructions are additional requirements\n``` enclosed contents are what needs to be translated', 'Translate the following text into {}:\n```\n{}\n```', '[{\"en\":\"English\",\"zh\":\"Chinese\"}]', 'Translation into the specified language');"
    ] {
        run $s
    }
}

export def make-session [created] {
    for s in [
        $"INSERT INTO sessions \(created, provider, model, temperature\)
        SELECT (Q $created), name, model_default, temp_default
        FROM provider where active = 1 limit 1;"
    ] {
        run $s
    }
}

export def edit [table pk] {
    run $"select * from ($table) where name = (Q $pk)"
    | first
    | to yaml
    | $"### config ($table)#($pk) \n($in)"
    | block-edit $"config-($table).XXX.yml"
    | from yaml
    | db-upsert $table name
}

export def session [] {
    run $"select * from provider as p join sessions as s
        on p.name = s.provider where s.created = (Q $env.OPENAI_SESSION);"
    | first
}

export def record [session, provider, model, role, content, token, tag] {
    let n = date now | format date '%FT%H:%M:%S.%f'
    run $"insert into messages \(session_id, provider, model, role, content, token, created, tag\)
        VALUES \((Q $session), (Q $provider), (Q $model), (Q $role), (Q $content), (Q $token), (Q $n), (Q $tag)\);"
}

export def messages [num = 10] {
    run $"select role, content from messages where session_id = (Q $env.OPENAI_SESSION) and tag = '' limit ($num)"
}
