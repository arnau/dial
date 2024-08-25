# Interactions with GitHub

const BASE_URL = "https://api.github.com"

export def "token decrypt" [] {
    ^op read $env.GITHUB_TOKEN_OP 
}

# 1Password is dreadfully slow.
export def --env "token env" [] {
    $env.GITHUB_TOKEN = (token decrypt)
}

export def "token read" [] {
    if ($env.GITHUB_TOKEN? | is-empty) {
        token decrypt
    } else {
        $env.GITHUB_TOKEN
    }
}

# Expects an input from a raw Link http header.
#
# This is a rather naive parser for IETF RFC 8288 Web Linking values.
#
# ## Example
#
# ```nu
# '<https://api.github.com/search/issues?q=repo%3Anushell%2Fnushell+type%3Apr+is%3Amerged+merged%3A%3E%3D2024-08-01&order=desc&per_page=2&page=2>; rel="next", <https://api.github.com/search/issues?q=repo%3Anushell%2Fnushell+type%3Apr+is%3Amerged+merged%3A%3E%3D2024-08-01&order=desc&per_page=2&page=42>; rel="last"' | from http link-header
# ```
export def "from http link-header" [] {
    $in
    | split row ","
    | each { $in | str trim | parse "<{url}>; rel=\"{rel}\"" }
    | update url { url decode }    
}

# Requests something from the GitHub API
#
# Response notes:
#
# x-ratelimit-reset * 1_000_000_000 | into datetime
# x-ratelimit-remaining
export def "fetch" [endpoint: string --query (-q): record] {
    let headers = {
        Accept: "application/vnd.github+json"
        X-GitHub-Api-Version: "2022-11-28"
        Authorization: $"Bearer (token read)"
    }
    let url = if ($query | is-not-empty) {
        $"($BASE_URL)/($endpoint)?($query | url build-query)"
    } else {
        $"($BASE_URL)/($endpoint)"
    }

    http get -f --headers $headers $url 
}

export def "octocat" [] {
    fetch "octocat" 
}

def pr_statuses [] {
    [open closed all]
}

def pr_sort [] {
    [created updated popularity long-running]
}

def pr_direction [] {
    [asc desc]
}

export def "pr list" [
    owner: string
    repo: string
    --state (-s): string@pr_statuses = closed
    --sort: string@pr_sort = updated
    --direction: string@pr_direction = desc
    --per-page: int = 50
    --page: int = 1
] {
    let query = {
        state: $state
        sort: $sort
        direction: $direction
        per_page: $per_page
        page: $page
    }

    fetch -q $query $"repos/($owner)/($repo)/pulls" 
}

# Converts record into search query string.
# Similar to `url build-query` but for search queries in GitHub.
export def "search build-query" []: [record -> string] {
    $in
    | items {|key, value| $"($key):($value)" }
    | str join " "
}

# Fetch the Pull Requests merged since the given date.
export def "pr list merged" [
    owner: string
    repo: string
    --since (-s): datetime # Date from when PRs were merged. Defaults to today.
    --direction: string@pr_direction = desc
    --per-page: int = 100
    --page: int = 1
] {
    let since = if ($since | is-empty) { date now } else { $since }
    let since_stamp = ($since | format date "%Y-%m-%d")
    let search = {
        repo: $"($owner)/($repo)"
        type: pr
        is: merged
        merged: $">=($since_stamp)"
    }
    let query = {
        q: ($search | search build-query)
        order: $direction
        per_page: $per_page
        page: $page
    }

    fetch -q $query $"search/issues" 
}
