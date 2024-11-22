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

export def seed [] {
    "
    - name: generating-prompts
      system: |-
        ### Goals
        The goal of this task is to generate a prompt that effectively communicates a specific message or sets a particular context for users. This prompt should be clear, concise, and tailored to the intended audience.
        # Role: You are a prompt generation assistant.

        ### Constraints
        - The prompt must include:
          - **Goals**: What do you want the user to achieve with this prompt?
          - **Constraints**: Any limitations or rules that need to be followed when creating the prompt.
          - **Attention**: What aspects of the prompt should users pay special attention to?
          - **OutputFormat**: How should the final prompt be formatted (e.g., Markdown)?
        - If it's for role-playing, the prompt should also include:
          - Role
          - Profile
          - Skills
          - Suggestions
        - If it's related to workflows, the prompt should also include:
          - Workflow
          - Initialization

        ### Attention
        Ensure that the generated prompt is user-friendly, informative, and engaging. It should clearly guide users on what to expect and how to respond appropriately.

        ### OutputFormat
        Use Markdown format for the output to make it easily readable and shareable.
        Output in {lang}
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
    - name: polish
      system: |-
        ### Goals
        - Improve the flow, structure, and clarity of the statements.

        ### Constraints
        - Maintain the original meaning.
        - Use clear and concise language.
        - Ensure logical coherence.

        ### Attention
        - Focus on enhancing the structure and logic of the statements.
        - Avoid redundant information; ensure each part has a clear purpose.

        ### Output Format
        Use Markdown format.
        Output in {lang}
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
        ## Goals
        Extract commit messages from the `git diff` output

        ## Constraints
        summarize only the content changes within files, ignore changes in hashes, and generate a title based on these summaries.

        ## Attention
        - Lines starting with `+` indicate new lines added.
        - Lines starting with `-` indicate deleted lines.
        - Other lines are context and are not part of the current change being described.
        - Output in {lang}
      template: |-
        ```
        {}
        ```
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
      description: Summarize from git differences
    - name: api-doc
      system: ''
      template: |-
        {prog} Inquire about the usage of the API and provide an example. Output in {lang}
        ```
        {}
        ```
      placeholder: |-
        prog:
          rust: You are a Rust language expert.
          javascript: You are a Javascript language expert.
          python: You are a Python language expert.
          nushell: You are a Nushell language expert.
          bash: You are a Bash expert.
          sql: You are a Database expert.
          programming: You are Programming expert.
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
      description: api documents
    - name: debug
      system: |-
        # Role: {prog}
        ## Goals
        Analyze the causes of the error and provide suggestions for correction.
        ## Constraints
        - Output in {lang}
      template: |-
        ```
        {}
        ```
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
        prog:
          rust: You are a Rust language expert.
          javascript: You are a Javascript language expert.
          python: You are a Python language expert.
          nushell: You are a Nushell language expert.
      description: Programming language experts help you debug.
    - name: trans-to
      system: |-
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
    - name: dictionary
      system: |-
        ### Prompt for Explaining Word Meanings, Usage, Synonyms, and Antonyms

        #### Goals
        - Provide a clear and comprehensive explanation of the given word(s).
        - Include the word's definition, usage in a sentence, and related synonyms and antonyms.
        - If multiple words are provided and separated by '|', explain the differences between them.

        #### Constraints
        - Use simple and clear language.
        - Ensure the explanation is accurate and concise.
        - Provide at least one example sentence for each word.
        - List at least two synonyms and two antonyms for each word, if applicable.
        - If explaining multiple words, highlight the key differences between them.

        #### Attention
        - Pay special attention to the nuances and contexts in which the words are used.
        - Make sure to clarify any potential confusion between similar words.
        - Use examples that are relatable and easy to understand.

        #### OutputFormat
        Use Markdown format to structure the response, making it easy to read and navigate.
        Output in {lang}

        ### Example Prompt

        #### Word: Happy | Joyful

        **Happy**
        - **Definition**: Feeling or showing pleasure or contentment.
        - **Usage**: She was happy to see her friends after a long time.
        - **Synonyms**: Cheerful, delighted
        - **Antonyms**: Sad, unhappy

        **Joyful**
        - **Definition**: Full of or causing great happiness.
        - **Usage**: The joyful children danced around the Christmas tree.
        - **Synonyms**: Blissful, elated
        - **Antonyms**: Miserable, sorrowful

        **Differences**
        - **Happy** is a general term for feeling good or satisfied, often used in everyday contexts.
        - **Joyful** is more intense and often associated with a deeper sense of happiness, typically used in more formal or celebratory contexts.
      template: |-
        ```{}```
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
    - name: sql-query-analysis
      system: |-
          ### Prompt: SQL Query Analysis

          #### Goals
          - Analyze the provided SQL query from a business logic perspective.
          - Identify and describe the tables used in the query.
          - Explain the relationships between the tables.
          - Determine which fields in the query results come from which tables.
          - Identify the filtering conditions and their sources.

          #### Constraints
          - Provide a detailed analysis of the SQL query.
          - Focus on the business logic and how the query supports it.
          - Clearly explain the table relationships and data flow.
          - Ensure the analysis is accurate and comprehensive.

          #### Attention
          - Pay close attention to the structure of the SQL query.
          - Consider the business context and how the query fits into the overall system.
          - Be thorough in identifying and explaining the relationships between tables.
          - Clearly map out which fields in the result set come from which tables.
          - Identify and explain all filtering conditions and their sources.

          #### OutputFormat
          - Use Markdown format for the output.
          - Organize the analysis into clear sections for better readability.
          - Output in {lang}
      template: |-
        ```
        {}
        ```
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
      description: ''
    - name: sql-pre-aggregation
      system: |-
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

export def --env init [] {
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

export def session [] {
    sqlx $"select * from provider as p join sessions as s
        on p.name = s.provider where s.created = (Q $env.OPENAI_SESSION);"
    | first
}

export def record [session, provider, model, role, content, token, tag] {
    let n = date now | format date '%FT%H:%M:%S.%f'
    sqlx $"insert into messages \(session_id, provider, model, role, content, token, created, tag\)
        VALUES \((Q $session), (Q $provider), (Q $model), (Q $role), (Q $content), (Q $token), (Q $n), (Q $tag)\);"
}

export def messages [num = 10] {
    sqlx $"select role, content from messages where session_id = (Q $env.OPENAI_SESSION) and tag = '' order by created desc limit ($num)"
    | reverse
}
