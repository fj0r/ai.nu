use ../../config.nu *
export-env {
    ai-config-env-tools run_python_code {
        schema: {
            description: "This function executes Python code in the current working directory. It can be used to run scripts, modules, or any Python code snippet.",
            parameters: {
                type: object,
                properties: {
                    code: {
                        type: string,
                        description: "The Python code to execute. This can be a single line or multiple lines of code."
                    },
                    filename: {
                        type: string,
                        description: "(Optional) The filename to save the code if running from a file. If not provided, the code will be executed directly."
                    },
                    timeout: {
                        type: number,
                        description: "(Optional) Maximum time in seconds to wait for the code execution before timing out. Default is no timeout."
                    }
                },
                required: [
                    code
                ]
            }
        }
        handler: {|x, ctx|
            let f = if ($x.filename? | is-empty) {
                mktemp --suffix .py
            } else {
                $x.filename
            }
            $x.code | save -f $f
            let o = python $f
            if ($x.filename? | is-empty) {
                rm -f $f
            }
            $o
        }
    }
    ai-config-env-tools run_sql_query {
        context: {||
            if ($env.PGAUTHINFO? | is-empty) {
                {
                    host: localhost
                    port: 5432
                    database: foo
                    username: foo
                    password: foo
                }
            } else {
                print $"(ansi red)load authinfo from ($env.PGAUTHINFO)(ansi reset)"
                open ($env.PGAUTHINFO | path expand)
            }
        }
        schema: {
            __description: {|ctx|
                $env.PGPASSWORD = $ctx.password
                let t = "SELECT table_schema || '.' || table_name AS full_table_name
                FROM information_schema.tables WHERE
                table_schema NOT IN ('pg_catalog', 'information_schema')
                AND table_type = 'BASE TABLE';"
                | psql -U $ctx.username -d $ctx.database -h $ctx.host -p $ctx.port
                $"This function executes a PostgreSQL query from a file located in the current directory. The file should contain valid SQL statements. including the following table: ($t)"
            }
            description: "This function executes a PostgreSQL query from a file located in the current directory. The file should contain valid SQL statements."
            parameters: {
                type: object,
                properties: {
                    query: {
                        type: string,
                        description: "The sql query to execute. This can be a single line or multiple lines of query."
                    },
                    filename: {
                        type: string,
                        description: "(Optional) The filename to save the query if running from a file. If not provided, the query will be executed directly."
                    },
                    timeout: {
                        type: number,
                        description: "(Optional) Maximum time in seconds to wait for the query execution before timing out. Default is no timeout."
                    }
                },
                required: [
                    query
                ]
            }
        }
        handler: {|x, ctx|
            let f = if ($x.filename? | is-empty) {
                mktemp --suffix .sql
            } else {
                $x.filename
            }
            $x.query | save -f $f
            $env.PGPASSWORD = $ctx.password
            let o = psql -U $ctx.username -d $ctx.database -h $ctx.host -p $ctx.port -f $f
            if ($x.filename? | is-empty) {
                rm -f $f
            }
            $o
        }
    }
}
