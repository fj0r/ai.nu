use ../../config.nu *
export-env {
    ai-config-env-tools get_weather {
        context: {||
            {
                observation_time: "12:35 PM"
                temparature: 16
                wind_speed: 17
                wind_dir: "W"
                pressure: 1016
                humidity: 87
                cloudcover: 100
                feelslike: 16
                visibility: 16
            }
        }
        schema: {
            description: 'Get the current weather in a given location'
            parameters: {
                type: object
                properties: {
                    location: {
                        type: string
                        description: "The city and state, e.g. San Francisco, CA"
                    },
                    unit: {
                        type: string
                        enum: {|ctx| [celsius fahrenheit] }
                    }
                }
                required: [location]
            }
        }
        handler: {|x, ctx|
            let location = $x.location
            let unit = $x.unit? | default ''
            sleep 2sec
            $ctx | insert unit $unit
        }
    }

    ai-config-env-tools get_current_location {
        context: {

        }
        schema: {
            description: 'Retrieves the current geographical location of the user. It can provide latitude, longitude, and optionally a formatted address.'
            parameters: {
                type: object
                properties: {}
                required: []
            }
        }
        handler: {|x, ctx|
        }
    }

    ai-config-env-tools web_fetch {
        context: {}
        schema: {
            description: "Fetch web content and convert it to Text or Markdown format.",
            parameters: {
              type: object
              properties: {
                url: {
                  type: string
                },
                format: {
                  type: string
                  enum: ["txt", "markdown", "html"],
                  description: "Output format (default: txt)"
                }
              },
              required: [url]
            }
        }
        handler: {|x, ctx|
            if ($ctx.proxy? | is-not-empty) {
                $env.http_proxy = $ctx.proxy
                $env.https_proxy = $ctx.proxy
            }
            let r = http get -r -e $x.url
            match $x.format? {
                markdown | md => {
                    $r | ^($env.HTML_TO_MARKDOWN? | default 'html2markdown')
                }
                html => { $r }
                _ => {
                    $r
                    | query web -q 'p, pre, div'
                    | flatten
                    | where { $in | str trim  | is-not-empty }
                    | str join (char newline)
                }
            }
        }
    }

    ai-config-env-tools curl {
        context: {
            proxy: ''
        }
        schema: {
            description: "Perform HTTP requests to fetch web content or submit data using curl. It takes a list of parameters that are passed directly to the curl command, excluding the 'curl' keyword itself."
            parameters: {
                type: object,
                properties: {
                    args: {
                        type: array,
                        description: "A list of arguments to pass to the curl command. These can include options like method, URL, headers, data, etc.",
                        items: {
                            type: string,
                            description: "Each argument as a string"
                        }
                    },
                }
                required: [
                    args
                ]
            }
        }
        handler: {|x, ctx|
            let x = if ($x | describe -d).type == 'list' { $x } else { $x.args }
            curl ...$x
        }
    }

    ai-config-env-tools web_search {
        context: {
            proxy: ''
        }
        schema: {
            description: "Perform a search using search engine. It can be used to find web pages, images, videos, or any other content based on provided keywords."
            parameters: {
                type: object,
                properties: {
                    query: {
                        type: string,
                        description: "The search terms or keywords"
                    },
                    num_results: {
                        type: number,
                        description: "The number of results to return"
                    },
                    language: {
                        type: string,
                        description: "The language of the search results"
                    },
                    search_type: {
                        type: string,
                        description: "The type of search",
                        enum: [
                            web,
                            image,
                            video
                        ]
                    }
                },
                required: [
                    query
                ]
            }
        }
        handler: {|x, ctx|
            let n = $x.num_results? | default 10
            let p = if ($ctx.proxy? | is-empty) {
                []
            } else {
                [--proxy $ctx.proxy]
            }
            ddgr --json query $x.query -n $n ...$p
        }
    }
}
