sqlite3 $env.AI_STATE
```sql
alter table provider add column adapter TEXT default 'openai';
alter table messages add column tool_calls TEXT;

CREATE TABLE IF NOT EXISTS placeholder (
    name TEXT PRIMARY KEY,
    yaml TEXT NOT NULL DEFAULT '{}'
);

CREATE INDEX idx_placeholder ON placeholder (name);
```

```nu
use llm/data.nu *
seed
```
