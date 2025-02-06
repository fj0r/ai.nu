$env.OPENAI_TOOLS_CONFIG = $env.OPENAI_TOOLS_CONFIG | merge deep {
    query_knowledge_base: {||
        {
            ragit_dir: ~/world/ragit
        }
    }
}

$env.OPENAI_TOOLS = $env.OPENAI_TOOLS | merge deep {
    query_knowledge_base: {
        schema:  {
            name: query_knowledge_base
            description: "This function allows you to query information from a knowledge base. It can be used to retrieve specific data or answers based on provided keywords or questions."
            parameters: {
                type: object
                properties: {
                    query: {
                        type: string
                        description: "The search terms or question to query the knowledge base"
                    }
                    num_results: {
                        type: number
                        description: "The number of results to return (optional)"
                    }
                    language: {
                        type: string
                        description: "The language of the query and results (optional)"
                    }
                    category: {
                        type: string
                        description: "The category of information to search within"
                        enum: {|config|
                            cd $config.ragit_dir
                            let r = ls | where type == dir | get name
                            $r
                        }
                    }
                }
                required: [
                    query
                    category
                ]
            }
        }
        handler: {|x, config|
            print ($x | table -e)
            print ($config | table -e)
            print $"cd ([$config.ragit_dir $x.category] | path join)"
            print $"ragit query '($x.query)'"
            return 'nushell 1.0 has not been released yet.'
        }
    }
}

ai-config-alloc-tools programming-expert -t [query_knowledge_base]
