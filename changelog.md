has_thinking
```
open $env.AI_STATE | query db "
    alter table model add column has_thinking boolean default 0;
"
```
has_search
```
open $env.AI_STATE | query db "
    alter table model add column has_search boolean default 0;
"
```


sqlite3 $env.AI_STATE
### model table
```
open $env.AI_STATE | query db "
    CREATE TABLE IF NOT EXISTS model (
        -- provider TEXT,
        name TEXT,
        has_fn BOOLEAN DEFAULT 1,
        PRIMARY KEY (name)
    );
"
```

###
```sql
open $env.AI_STATE | query db "alter table provider add column adapter TEXT default 'openai';"
open $env.AI_STATE | query db "alter table messages add column tool_calls TEXT;"

open $env.AI_STATE | query db "CREATE TABLE IF NOT EXISTS placeholder (
    name TEXT PRIMARY KEY,
    yaml TEXT NOT NULL DEFAULT '{}'
);"

open $env.AI_STATE | query db "CREATE INDEX idx_placeholder ON placeholder (name);"

```

```nu
use llm/data.nu *
seed
```

### session_id

The primary key of the sessions table has been changed from `created TEXT` to `id INTEGER PRIMARY KEY`. Two new fields, `parent_id` and `offset`, have been added to support more flexible session management, such as "Conversation Forking".

The `session_id` field in the messages table has also been affected. The existing `created TEXT` cannot be simply converted to INTEGER (although it is not impossible, for example, by modifying the string to contain only numbers).

The simplest migration approach would be to recreate these two tables.

```sql
drop table sessions;
CREATE TABLE IF NOT EXISTS sessions (
    id INTEGER PRIMARY KEY,
    parent_id INTEGER DEFAULT -1,
    offset INTEGER DEFAULT -1,
    created TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%f','now')),
    provider TEXT NOT NULL,
    model TEXT NOT NULL,
    temperature REAL NOT NULL
);
CREATE INDEX idx_sessions_id ON sessions (id);
CREATE INDEX idx_sessions_pid ON sessions (parent_id);
drop table messages;
CREATE TABLE IF NOT EXISTS messages (
    session_id INTEGER REFERENCES sessions(id),
    provider TEXT,
    model TEXT,
    role TEXT,
    content TEXT,
    tool_calls TEXT,
    token INTEGER,
    created TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%f','now')),
    tag TEXT
);
CREATE INDEX idx_messages ON messages (session_id);
```

###
```
open $env.AI_STATE | query db 'alter table placeholder add column description text'
```
