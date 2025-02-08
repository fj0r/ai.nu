sqlite3 $env.AI_STATE
```sql
alter table provider add column adapter TEXT default 'openai';
alter table messages add column tool_calls TEXT;
```
