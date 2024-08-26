# Interactions with GitHub
use ./error.nu *
use ./token.nu
use ./http.nu

const BASE_URL = "https://api.github.com"

# Requests something from the GitHub API
#
# Response notes:
#
# x-ratelimit-reset * 1_000_000_000 | into datetime
# x-ratelimit-remaining
export def "fetch" [] {
    let url = $in
    let token = try { $env.GITHUB_TOKEN } catch {
        fail "Expected an environment variable named `GITHUB_TOKEN`"
    }
    let headers = {
        Accept: "application/vnd.github+json"
        X-GitHub-Api-Version: "2022-11-28"
        Authorization: $"Bearer (token read $token)"
    }

    http get -f --headers $headers $url 
}

# Composes a GitHub API URL.
export def "url join" [endpoint: string --query (-q): record] {
    [
        $"($BASE_URL)/($endpoint)"
        ($query | url build-query)
    ]
    | compact --empty
    | str join "?"
}


export def "octocat" [] {
    url join "octocat"
    | fetch 
}

module completer {
    export def pr_statuses [] {
        [open closed all]
    }

    export def pr_sort [] {
        [created updated popularity long-running]
    }

    export def pr_direction [] {
        [asc desc]
    }
}
use completer


# Converts record into search query string.
# Similar to `url build-query` but for search queries in GitHub.
export def "search build-query" []: [record -> string] {
    $in
    | items {|key, value|
          match ($value | describe --detailed | get type) {
              list => ($value | each { $"($key):($in)" })
              string => $"($key):($value)"
              $ty => (fail $"($ty) is not supported in search queries.")
          }
      }
    | flatten
    | str join " "
}

# Fetches a list page and provides the result and the URL to the next page.
#
# To be used with `generate`
export def "fetch page" [] {
    let url = $in

    if ($url | is-not-empty) {
        let res = $url | fetch        


        if ($res.status != 200) {
            fail $"The request to GitHub failed with error ($res.status)"
        }

        {out: $res.body.items, next: ($res | http next)}
    }
}


# Search issues and pull requests.
#
# The paginated result is flattened into a single streamed table.
#
# See: https://docs.github.com/en/rest/search/search?apiVersion=2022-11-28#search-issues-and-pull-requests
export def "search" [
    query: record # A record containing the query.
    --direction: string@"completer pr_direction" = desc
    --per-page: int = 100
    --page: int = 1
] {
    let query = {
        q: ($query | search build-query)
        order: $direction
        per_page: $per_page
        page: $page
    }
     
    generate {fetch page} (url join -q $query $"search/issues")
    | flatten
}

# Retrieves the list of merged Pull Requests since the given date for the given repositories.
export def "pr list merged" [
    --since (-s): datetime # Date from when PRs were merged. Defaults to today.
    --direction: string@"completer pr_direction" = desc
    --per-page: int = 100
    --page: int = 1
    ...repos
] {
    let since = if ($since | is-empty) { date now } else { $since }
    let since_stamp = ($since | format date "%Y-%m-%d")
    let query = {
        repo: $repos
        type: pr
        is: merged
        merged: $">=($since_stamp)"
    }

    search --direction $direction --per-page $per_page --page $page $query
}
