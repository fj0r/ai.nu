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
            description: 'This function retrieves the current geographical location of the user. It can provide latitude, longitude, and optionally a formatted address.'
            parameters: {
                type: object
                properties: {}
                required: []
            }
        }
        handler: {|x, ctx|
        }
    }

    ai-config-env-tools curl {
        context: {
            proxy: ''
        }
        schema: {
            description: "This function allows you to make HTTP requests using curl. It takes a list of parameters that are passed directly to the curl command, excluding the 'curl' keyword itself."
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
            curl ...$x.args
        }
    }
    ai-config-env-tools web_search {
        context: {
            proxy: ''
        }
        schema: {
            description: "This function allows you to perform a search using search engine. It can be used to find web pages, images, videos, or any other content based on provided keywords.",
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
