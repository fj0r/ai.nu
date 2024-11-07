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
            system: $env.OPENAI_PROMPT_TEMPLATE
            template: "```\n{}\n```"
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

export def upsert-function [--delete --action: closure] {
    $in | table-upsert --action $action --delete=$delete {
        table: function
        pk: [name]
        default: {
            name: ''
            description: ''
            parameters: {}
        }
        filter: {
            out: {
                parameters: { $in | to yaml }
            }
            in: {
                parameters: { $in | from yaml }
            }
        }
    }
}

export def --env init [] {
    if 'OPENAI_DB' not-in $env {
        $env.OPENAI_DB = [$nu.data-dir 'openai.db'] | path join
    }
    if 'OPENAI_PROMPT_TEMPLATE' not-in $env {
        $env.OPENAI_PROMPT_TEMPLATE = "_: |-
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
            " | from yaml | get _
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
            placeholder TEXT NOT NULL DEFAULT '{}',
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
    ] {
        run $s
    }
    "
    - name: generating-prompts
      system: |-
        # Role: You are a prompt generation assistant.
        ## Attention:
        - The prompt should include:
          - Goals
          - Constraints
          - Attention
          - OutputFormat
        - If it's for role-playing, the prompt should also include:
          - Role
          - Profile
          - Skills
          - Suggestions
        - If it's related to workflows, the prompt should also include:
          - Workflow
          - Initialization
        ## OutputFormat
        - Use Markdown format for the output
        ## Constraints
        - Output in {lang}
      template: '{}'
      placeholder: |-
        lang:
          en: English
          fr: French
          es: Spanish
          de: German
          zh: Chinese
          jp: Janpanese
          ko: Korean
      description: ''
    - name: text-summary
      system: |-
        ### Text Summarization

        #### Goals
        - Generate a concise and coherent summary of the provided text.
        - Ensure that the summary captures the key points and main ideas of the original text.

        #### Constraints
        - The summary should be no more than 30% of the original text length.
        - Do not include any code blocks in the summary.
        - Avoid including website navigation or operational instructions.
        - Output in {lang}

        #### Attention
        - Focus on retaining the most important information and eliminating redundant details.
        - Maintain the original tone and style of the text as much as possible.

        #### OutputFormat
        - Use Markdown format for the output.
        - Ensure that the summary is well-structured and easy to read.

      template: '{}'
      placeholder: |-
        lang:
          en: English
          fr: French
          es: Spanish
          de: German
          zh: Chinese
          jp: Janpanese
          ko: Korean
      description: ''
    - name: json-to
      system: |-
        ## Goals
        - Analyze the following JSON data to convert it into a {lang} {object}.
        ## Constraints
        - Do not explain.
      template: |-
        ```
        {}
        ```
      placeholder: |-
        lang:
          jsonschema: JsonSchema
          rs: Rust
          hs: Haskell
          ts: TypeScript
          py: Python pydantic
          nu: Nushell
          psql: PostgreSQL
          mysql: MySQL
          slite: Sqlite
        object:
          type: Type
          struct: Struct
          class: Class
          trait: Trait
          interface: Interface
          table: Table
      description: Analyze JSON content, converting it into
    - name: git-diff-summary
      system: |-
        ## Role
        You are a git diff summary assistant.

        ## Goals
        Extract commit messages from the `git diff` output

        ## Constraints
        summarize only the content changes within files, ignore changes in hashes, and generate a title based on these summaries.

        ## Attention
        - Lines starting with `+` indicate new lines added.
        - Lines starting with `-` indicate deleted lines.
        - Other lines are context and are not part of the current change being described.
      template: |-
        ```
        {}
        ```
      placeholder: '{}'
      description: Summarize from git differences
    - name: api-doc
      system: ''
      template: |-
        {lang} Inquire about the usage of the API and provide an example.
        ```
        {}
        ```
      placeholder: |-
        lang:
          rust: You are a Rust language expert.
          javascript: You are a Javascript language expert.
          python: You are a Python language expert.
          nushell: You are a Nushell language expert.
          bash: You are a Bash expert.
          sql: You are a Database expert.
          programming: You are Programming expert.
      description: api documents
    - name: debug
      system: |-
        # Role: {lang}
        ## Goals
        Analyze the causes of the error and provide suggestions for correction.
        ## Constraints
      template: |-
        ```
        {}
        ```
      placeholder: |-
        lang:
          rust: You are a Rust language expert.
          javascript: You are a Javascript language expert.
          python: You are a Python language expert.
          nushell: You are a Nushell language expert.
      description: Programming language experts help you debug.
    - name: synonyms
      system: ''
      template: |-
        解释以下词语的区别，并介绍相关的近义词和反义词
        ```{}```
      placeholder: '{}'
      description: 近义词解析
    - name: trans-to
      system: |-
        ## Role
        You are a translation assisant

        ## Goals
        Translate the following text into {lang}

        ## Constraints
        Only provide the translated content without explanations
        Do not enclose the translation result with quotes

        ## Attention
        Other instructions are additional requirements
        If it is in markdown format, do not translate code blocks
      template: |-
        {}
      placeholder: |-
        lang:
          en: English
          fr: French
          es: Spanish
          de: German
          ru: Russian
          ar: Arabic
          zh: Chinese
          ja: Janpanese
          ko: Korean
      description: Translation into the specified language
    - name: git-diff-summary-zh
      system: |-
        ## Role
        你是git变更总结小助手
        ## Goals
        从git diff 中提取提交日志
        ## Constraints
        仅总结文件内容的变化，忽略哈希值的变化，并生成一个标题
        ## Attention
        以`+`开头的行是新增的行
        以 `-` 开头的行是删除的行
        其它行是上下文，不是本次变更内容
      template: |-
        ```
        {}
        ```
      placeholder: '{}'
      description: 生成git提交信息
    - name: bilingual-translation
      system: You are a translation expert. If the user sends you Chinese, you will translate it into English. If the user sends you English, you will translate it into Chinese. You are only responsible for translation and should not answer any questions.
      template: |-
        translate below:
        ```
        {}
        ```
      placeholder: '{}'
      description: ''
    - name: dictionary
      system: ''
      template: |-
        Explain the meaning, usage, list synonyms and antonyms of the following words:
        ```{}```
      placeholder: '{}'
      description: dictionary
    - name: dictionary-zh
      system: ''
      template: |-
        解释以下单词含义，用法，并列出同义词，近义词和反义词:
        ```{}```
      placeholder: '{}'
      description: dictionary
    - name: journal
      system: |
        ## Role: 工作助手

        ## Goals
        将下面的内容整理为工作日志

        ## Constraints
        要有感悟

        ## Attention
        - ☐ 是未完成的
        - 🗹 是已完成的
      template: '{}'
      placeholder: '{}'
      description: ''
    - name: name-helper
      system: |
        # Role: name helper
        ## Attention:
        include elements in description as much as possible
        ## Constraints:
        keep names short clear and unambiguous
        ## Goals:
        provide a suitable name based on user description
        ## OutputFormat:
        output only the name
        use lowercase letters and underscores to separate words
      template: '{}'
      placeholder: '{}'
      description: Naming suggestions
    - name: analyze-sql-statement
      system: |-
        # Role: You are a database expert
        ## Goals:
        - Receive query statements
        - Statistically relevant tables, and
            - Extract fields that appear in the results
            - Extract fields related to filtering conditions
            - Analyze dependencies
                - Which fields, when changed, will cause the results to change
                - Which filtering conditions, when changed, will cause the results to change

        ## Example:
        Input:
        ```
        select a.x, b.y, c.z
        from a
        join b on a.id = b.a_id
        join c on b.c_id = c.id
        where a.h > 1
          and b.i = 2
        ```
        Output:
        ```
        Tables involved include:
        - name: a
          select:
          - x
          where:
          - h
        - name: b
          select:
          - y
          where:
          - i
        - name: c
          select:
          - z
        ```
      template: |-
        ```
        {}
        ```
      placeholder: '{}'
    - name: sql-pre-aggregation
      system: |-
        # Role: 你是一名数据库优化专家
        ## Goals:
        - 接受维度、指标和sql查询
        - 根据查询创建物化视图
        - 给出在物化视图上查询的示例
        ## Attention:
        - 按维度分组
          - 如果维度是日期时间类型，先使用time_bucket截断
        - 按指标聚合
          - 默认使用 sum 聚合函数
        - 如果过滤条件出现在维度中，在物化视图中去除
        ## Constraints:
        - 输出合法的 PostgreSQL 语句
        - 不要考虑刷新策略相关问题
        ## OutputFormat:
      template: |-
        ```
        {}
        ```
      placeholder: '{}'
      description: matrialized view
    "
    | from yaml | each { $in | upsert-prompt }
    "
    - name: get_current_weather
      description: 'Get the current weather in a given location'
      parameters: |-
        type: object
        properties:
          location:
            type: string
            description: The city and state, e.g. San Francisco, CA
          unit:
            type: string
            enum:
            - celsius
            - fahrenheit
        required:
        - location
    "
    | from yaml | each { $in | upsert-function }
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
    run $"select role, content from messages where session_id = (Q $env.OPENAI_SESSION) and tag = '' order by created desc limit ($num)"
    | reverse
}
