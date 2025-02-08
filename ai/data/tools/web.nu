export-env {
    $env.AI_TOOLS = $env.AI_TOOLS | merge {
        get_weather: {
            config: {||
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
                          enum: {|config| [celsius fahrenheit] }
                        }
                    }
                    required: [location]
                }
            }
            handler: {|x, config|
                let location = $x.location
                let unit = $x.unit? | default ''
                sleep 2sec
                $config | insert unit $unit
            }
        }
        search_web: {
            schema: {
                description: 'This function allows you to perform a search using search engine. It can be used to find web pages, images, videos, or any other content based on provided keywords.'
                parameters: {
                    type: object
                    properties: {
                        query: {
                          type: string
                          description: "The search terms or keywords"
                        }
                        num_results: {
                          type: number
                          description: "The number of results to return"
                        }
                        language: {
                          type: string
                          description: "The language of the search results"
                        }
                        search_type: {
                          type: string
                          description: "The type of search"
                          enum: [web image video]
                        }
                    }
                    required: [query]
                }
            }
            handler: {|x, config|
                return 'hello'
            }
        }
    }
}
