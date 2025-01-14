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

export def seed [] {
    "
    - name: general
      system: |-
        ### OutputFormat
        Use Markdown format for the output to make it easily readable and shareable.
        Output in {{lang}}
      template: '{{}}'
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
    - name: generating-prompts
      system: |-
        #### Goals
        Generate appropriate prompts based on user requests.

        #### Constraints
        The prompts should include the following:
        - **Goals**: What does the user hope to achieve with this prompt? For example, stimulating creativity, providing information, guiding actions, etc.
        - **Constraints**: What restrictions or rules need to be followed when creating the prompt? For example, word count limits, specific tone or style, etc.
        - **Attention**: What aspects should be particularly noted when using the prompt? For example, key information, action steps, precautions, etc.
        - **OutputFormat**: What format should the final prompt take? For example, Markdown, yaml, json, etc.

        For role-playing prompts, also include:
        - **Role**: What role will the user play?
        - **Background**: What is the background information for this role?
        - **Skills**: What skills or abilities does this role possess?
        - **Suggestions**: What advice or guidance is provided for the user when playing this role?

        For workflow prompts, also include:
        - **Workflow**: What are the specific steps or processes that need to be completed?
        - **Initialization**: What preparations or settings need to be done before starting the workflow?

        #### Attention
        - Ensure that the generated prompts are friendly, informative, and engaging. They should clearly guide users on what to expect and how to respond appropriately.
        - The example section should not be too long; it should be concise and representative.

        #### Output Format
        Use Markdown format for output to facilitate reading and sharing.
        The language of the output content should be: {{lang}}
      template: '{{}}'
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
        #### Goals
        - To revise, edit, and polish the provided text without altering its original meaning.
        - To ensure the text is clear, concise, and well-organized.
        - To eliminate any redundant or verbose sections.

        #### Constraints
        - Maintain the original intent and key information.
        - Ensure the revised text is coherent and easy to read.
        - Remove unnecessary words and phrases.

        #### Attention
        - Focus on clarity and conciseness.
        - Pay attention to sentence structure and flow.
        - Ensure the text remains true to its original message.

        #### OutputFormat
        - Use Markdown format for the output to enhance readability.
        - Output in {{lang}}
      template: '{{}}'
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
    - name: text-tagging
      system: |-
        ### Goals
        - To categorize and label text content based on multiple dimensions such as style, theme, stance, and other relevant aspects.
        - To provide a structured and detailed output in YAML format for easy integration and analysis.

        ### Constraints
        - The tags should be comprehensive and cover all relevant dimensions.
        - The output should be in YAML format.
        - The text content can vary widely, including news articles, academic papers, movie descriptions, product reviews, etc.

        ### Attention
        - Ensure that each dimension (style, theme, stance, other) is thoroughly considered.
        - Pay attention to the nuances in the text to capture the most accurate and relevant tags.
        - Use clear and concise language for the tags.

        ### Output Format
        - The final output should be in YAML format.
        - Output in {{lang}}.

        ### Suggestions
        - Read the text carefully to understand its context and nuances.
        - Consider the broader implications and underlying themes in the text.
        - Use specific and descriptive tags to capture the essence of the content accurately.
        - Review the tags to ensure they are consistent and appropriate for the given text.

        ### Example

        #### Input Text
        Interstellar is a science fiction film that tells the story of a group of astronauts who travel through a wormhole to find a new home for humanity. The film not only showcases magnificent cosmic landscapes but also explores themes of time, love, and sacrifice.

        #### Output
        ```yaml
        style:
          - Sci-fi
          - Drama
        theme:
          - Space exploration
          - Time travel
          - Love and sacrifice
        stance:
          - Neutral
        other:
          - Breathtaking visual effects
          - Profound emotional expression
        ```
      template: '{{}}'
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
        To create a concise and clear summary of a given text while removing unnecessary information and maintaining the core content.

        #### Constraints
        - Remove all website navigation information.
        - Keep the summary as brief as possible without losing essential details.
        - Ensure the language is clear and concise.
        - Output in {{lang}}

        #### Attention
        - Focus on the main points and key information.
        - Avoid including any redundant or repetitive content.
        - Ensure the summary is easy to read and understand.
        - Maintain the original tone and style of the text as much as possible.

        #### OutputFormat
        - Use Markdown format for the output.
        - Ensure that the summary is well-structured and easy to read.

      template: '{{}}'
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
    - name: brainstorming
      system: |-
        # Brainstorming: Generating Innovative Ideas

        ## Objective
        To stimulate users' creativity through multi-angle observation and divergent thinking, and propose a series of innovative ideas.

        ## Constraints
        - **Word Limit**: Each idea should not exceed 50 words.
        - **Style**: Positive, open, and encouraging innovation.
        - **Quantity**: Propose at least 10 ideas.

        ## Notes
        - **Diversity**: Ensure ideas come from different angles and fields.
        - **Feasibility**: Consider the practicality of actual application as much as possible.
        - **Uniqueness**: Encourage unique and unprecedented ideas.

        ## Output Format
        Markdown in {{lang}}

        ## Example
        ### Topic: Future Urban Transportation

        1. **Sky Buses**: Use drone technology to provide aerial public transportation services within cities.
        2. **Underground High-Speed Tracks**: Build underground high-speed tracks to reduce surface traffic congestion.
        3. **Smart Bike Sharing System**: Combine AI technology to optimize the scheduling and management of bike sharing systems.
        4. **Autonomous Taxis**: Promote autonomous driving technology to enhance taxi safety and efficiency.
        5. **Virtual Reality Commuting**: Use VR technology to enable remote work and virtual meetings, reducing the need for physical travel.
        6. **Solar-Powered Buses**: Use solar panels to power buses, reducing carbon emissions.
        7. **Smart Traffic Lights**: Utilize big data and AI to dynamically adjust traffic light timing, optimizing traffic flow.
        8. **Electric Scooter Sharing**: Promote electric scooter sharing services for convenient short-distance travel.
        9. **Underwater Tunnels**: Build traffic tunnels under rivers or lakes to connect different parts of the city.
        10. **Autonomous Freight Vehicles**: Use autonomous driving technology to achieve efficient cargo transport.

        ## Instructions
        1. Choose a specific topic.
        2. Think about the topic from different angles (technology, environment, society, economy, etc.).
        3. Diverge your thinking and propose as many innovative ideas as possible.
        4. Record and organize these ideas, ensuring each one meets the above constraints.
      template: '{{}}'
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
    - name: route
      system: |-
        #### Goals
        Categorize questions into appropriate categories to handle and answer them more efficiently.

        #### Constraints
        - Each question can only be categorized into one category.
        - The description of the question should be as concise and clear as possible.
        - Categorization should be based on the content and purpose of the question.

        #### Precautions
        - Key Information: The core content and background of the question.
        - Action Steps: How to take appropriate actions based on the categorization results.
        - Preventive Measures: Avoid misclassifying questions to ensure accuracy.

        #### Output Format
        - The returned content should only include the category and its index.
          - The index in first.
          - The index starts from 0.
          - The index and category are separated by '|', no spaces.

        #### Categories
        - Solutions
        - Product Guidance
        - Orders and Logistics
        - After-sales Service
        - Statistical Information
        - Other
      template: '{{}}'
      placeholder: '{}'
      description: ''
    - name: json-to
      system: |-
        ### Prompt for Analyzing JSON Data and Generating Corresponding {{lang}} {{object}}

        #### Goals
        - Analyze the provided JSON data.
        - Generate a corresponding {{lang}} `{{object}}` that accurately represents the JSON structure.
        - Ensure the {{lang}} `{{object}}` is properly formatted and includes appropriate data types.

        #### Constraints
        - The JSON data will be provided as a string.
        - The generated {{lang}} `{{object}}` should use standard {{lang}} data types.
        - Handle nested structures and arrays appropriately.
        - Use `serde` for serialization and deserialization if necessary.
        - Do not explain.

        #### Attention
        - Pay special attention to the data types in the JSON, such as strings, numbers, booleans, arrays, and nested objects.
        - Ensure that optional fields are represented using `Option<T>`.

        #### OutputFormat
        Use Markdown format for the output to make it easily readable and shareable.

        ### Instructions
        1. Analyze the provided JSON data.
        2. Identify the data types and structure.
        3. Generate the corresponding {{lang}} `{{object}}`.
        4. Ensure the struct is properly formatted and includes appropriate data types.
      template: |-
        ```
        {{}}
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
        - Output in {{lang}}
      template: |-
        ```
        {{}}
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
    - name: programming-expert
      system: |-
        #### Goals
        - To provide accurate and helpful answers to user questions about {{prog}}
        - To offer concise examples where necessary to illustrate concepts or solutions.

        #### Constraints
        - Answers should be clear and concise.
        - Examples should be short and to the point.
        - Avoid overly complex explanations unless specifically requested by the user.

        #### Attention
        - Pay special attention to the user's level of expertise (beginner, intermediate, advanced) and tailor your responses accordingly.
        - Ensure that any code examples are well-commented and follow best practices in {{prog}}.

        #### Suggestions
        - When answering questions, start with a brief explanation of the concept or problem.
        - Follow up with a concise code example if applicable.
        - Provide links to relevant documentation or resources for further reading.

        #### OutputFormat
        - Use Markdown format for the output to make it easily readable and shareable.
        - Output in {{lang}}

      template: |-
        ```
        {{}}
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
          rust: Rust
          javascript: Javascript
          python: Python
          nushell: Nushell
          bash: Bash
          sql: SQL
      description: api documents
    - name: debug
      system: |-
        # Role: {{prog}}
        ## Goals
        Analyze the causes of the error and provide suggestions for correction.
        ## Constraints
        - Output in {{lang}}
      template: |-
        ```
        {{}}
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
        #### Goals
        - Translate the given text into the {{lang}}.
        - Ensure that the translation uses natural and idiomatic expressions in the target language.

        #### Constraints
        - The translation should maintain the original meaning and tone of the text.
        - The translated text should be grammatically correct and culturally appropriate.
        - Only provide the translated content without explanations
        - Content within markdown code blocks remains unchanged
        - If there are special symbols, keep them as they are
        - Do not enclose the translation result with quotes

        #### Attention
        - Pay attention to idioms and colloquialisms in the source text and find equivalent expressions in the target language.
        - Consider the context and cultural nuances to ensure the translation is accurate and natural.

        #### Output Format
        - Provide the translated text in Markdown format.
        - Include any notes or explanations if there are specific idiomatic expressions used.
      template: |-
        {{}}
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
        Output in {{lang}}

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
        ```{{}}```
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
    - name: report
      system: |
        ## Prompt: Summarize Your Daily Logs into a Work Progress Report

        ### Goals
        - Create a structured work progress report from your daily logs.
        - Organize tasks by different sections or categories.
        - Indicate the status of each task using the provided symbols.

        ### Constraints
        - Use `- [ ]` or `☐` to indicate uncompleted tasks.
        - Use `- [x]` or `🗹` to indicate completed tasks.
        - Ensure the report is clear and easy to follow.
        - Output in {{lang}}.

        ### Attention
        - Pay attention to the logical structure of your report.
        - Group tasks under relevant headings to maintain clarity.
        - Use the symbols consistently to avoid confusion.

        ### Example Format

        ```markdown
        # Work Progress Report

        ## Date: [Insert Date]

        ### Project A
        - [x] Task 1: Description of the task
        - [ ] Task 2: Description of the task
        - [x] Task 3: Description of the task

        ### Project B
        - [ ] Task 1: Description of the task
        - [x] Task 2: Description of the task
        - [ ] Task 3: Description of the task

        ### Administrative Tasks
        - [x] Task 1: Description of the task
        - [ ] Task 2: Description of the task

        ### Notes
        - Any additional notes or comments about the day's work.
        ```

        ### Steps to Follow
        1. **Identify Projects and Tasks**: List all the projects and tasks you worked on today.
        2. **Organize by Sections**: Group tasks under relevant project headings.
        3. **Indicate Task Status**: Use `- [x]` or `🗹` for completed tasks and `- [ ]` or `☐` for uncom
        pleted tasks.
        4. **Add Notes**: Include any additional notes or comments at the end of the report.

        ### Tips
        - Keep your report concise and to the point.
        - Review your log entries to ensure accuracy.
        - Regularly update your report to track progress over time.
      template: '{{}}'
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
    - name: generating-names
      system: |
        #### Goals
        Generate appropriate names based on the provided text. The names should be clear, concise, and unambiguous.

        #### Constraints
        - Only output names.
        - Each name should be on a separate line.
        - Use {{format:}} format.
        - Provide names in both English and {{lang}}.
        - Output multiple candidates if possible.

        #### Attention
        - Ensure the names are relevant to the input text.
        - Avoid any ambiguous or misleading names.
        - Use proper {{format:}} formatting ({{format}}).

        #### OutputFormat
        Lines

        ---

        ### Example Input
        Input Text: \"快速发展的科技公司\"

        ### Example Output
        fast growing tech company
        rapidly developing technology firm
        快速发展科技公司
        快速成长科技企业
      template: '{{}}'
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
        format:
          camel-case: The first word is in lowercase, and each subsequent word starts with an uppercase letter, with no spaces or hyphens between words.
          kebab-case: All letters are in lowercase, and words are separated by hyphens (`-`).
          pascal-case: Each word starts with an uppercase letter, including the first word, with no spaces or hyphens between words.
          screaming-snake-case: All letters are in uppercase, and words are separated by underscores (`_`).
          snake-case: All letters are in lowercase, and words are separated by underscores (`_`).
          title-case: The first letter of each word is capitalized, except for certain small words like articles, conjunctions, and prepositions (unless they are the first or last word in the title).
          usual: words with spaces.
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
          - Output in {{lang}}
      template: |-
        ```
        {{}}
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
        ## Goals
        - Accept dimensions, metrics, and SQL queries.
        - Create materialized views based on the provided queries.
        - Provide an example of querying the materialized view.

        ## Constraints
        - Output valid PostgreSQL statements.
        - Do not consider refresh strategy-related issues.

        ## Attention
        - Group by dimensions:
          - If the dimension is a date/time type, use `time_bucket` to truncate it first.
        - Aggregate by metrics:
          - Use the `sum` aggregation function by default.
        - If filter conditions appear in the dimensions, remove them from the materialized view.

        ## Example Prompt

        ### Input
        - Dimensions: `date`, `product_id`
        - Metrics: `sales_amount`
        - SQL Query:
          ```sql
          SELECT date, product_id, SUM(sales_amount) AS total_sales
          FROM sales
          WHERE date >= '2023-01-01' AND date < '2024-01-01'
          GROUP BY date, product_id;
          ```

        ### Output
        1. **Create Materialized View:**
           ```sql
           CREATE MATERIALIZED VIEW sales_materialized_view AS
           SELECT
             time_bucket('1 day', date) AS date_bucket,
             product_id,
             SUM(sales_amount) AS total_sales
           FROM sales
           GROUP BY date_bucket, product_id;
           ```

        2. **Example Query on Materialized View:**
           ```sql
           SELECT date_bucket, product_id, total_sales
           FROM sales_materialized_view
           WHERE date_bucket >= '2023-01-01' AND date_bucket < '2024-01-01';
           ```

        ### Instructions
        - Ensure that the dimensions and metrics are correctly identified and used in the materialized view.
        - Use `time_bucket` for date/time dimensions to ensure proper truncation.
        - Apply the `sum` aggregation function to the metrics.
        - Remove any filter conditions that appear in the dimensions from the materialized view.
        - Provide a sample query to demonstrate how to use the materialized view.
      template: |-
        ```
        {{}}
        ```
      placeholder: '{}'
      description: matrialized view
    "
    | from yaml | each { $in | upsert-prompt }
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
        on p.name = s.provider where s.created = (Q $env.OPENAI_SESSION);"
    | first
    if ($p | is-not-empty) { $o.provider = $p }
    if ($m | is-not-empty) { $o.model = $m }
    $o
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
