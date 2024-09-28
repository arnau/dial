# Interactions with GitHub


use ./completer.nu
use ./error.nu *
use ./token.nu
use ./http.nu


def base-url [] {
    "https://api.github.com"
}

# Composes a token for the GitHub API.
def credentials [] {
    let token = try-env GITHUB_TOKEN

    token read $token
}

# Requests something from the GitHub API.
#
# Response notes:
#
# x-ratelimit-reset * 1_000_000_000 | into datetime
# x-ratelimit-remaining
export def "fetch" []: [string -> table] {
    let url = $in
    let token = credentials
    let headers = {
        Accept: "application/vnd.github+json"
        X-GitHub-Api-Version: "2022-11-28"
        Authorization: $"Bearer ($token)"
    }

    http get --full --allow-errors --headers $headers $url 
}

export def "rate-limit" [] {
    base-url
    | http url join "rate_limit"
    | fetch
}

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
# To be used with `generate`. Most likely you want to use `fetch all`
def "fetch page" [] {
    let input = $in

    if (($input.url | is-not-empty) and ($input.allowance > 0)) {
        let res = $input.url | fetch        

        # TODO: Return the response body as a page record instead of failing.
        if ($res.status != 200) {
            fail $"The request to GitHub failed with error ($res.status)"
        }

        let out = {
            status: $res.status
            ratelimit: ($res | http ratelimit)
            url: $input.url
            next_url: ($res | http next)
            data: $res.body
        }

        {out: $out, next: {url: $out.next_url, allowance: $out.ratelimit.remaining}}
    }
}

# Fetches all pages from a starting URL.
export def "fetch all" [
    resource: string@"completer gh_ratelimit_resources" # A GitHub rate limit resource type.
]: [string -> table] {
    let url = $in
    let allowance = (rate-limit | get body.resources | get $resource | get remaining)
    let input = {
        allowance: $allowance
        url: $url
    }

    generate {fetch page} $input
}


# Search issues and pull requests.
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
     
    base-url
    | http url join -q $query $"search/issues"
    | fetch all "search"
}

export def "pr list normalise" [] {
    $in
    | flatten
    | select number repository_url url timeline_url title created_at updated_at closed_at user.login
    | rename --column {"user.login": "creator"}
    | insert repo {|row|
          $row.repository_url
          | parse --regex '(?<repo>[^\/]+\/[^\/]+)$'
          | get repo.0
      }
}



# Retrieves the list of merged Pull Requests since the given date for the given repositories.
#
# ```nu
# GITHUB_TOKEN=$env.GITHUB_TOKEN_OP dial github pr list merged -s 2024-08-01 nushell/nushell nushell/nu_scripts
# ```
export def "pr list merged" [
    --since (-s): datetime # Date from when PRs were merged. Defaults to today.
    --direction: string@"completer pr_direction" = desc
    --per-page: int = 100
    --page: int = 1
    query: record
] {
    let since = if ($since | is-empty) { date now } else { $since }
    let since_stamp = ($since | format date "%Y-%m-%d")
    let query = {
        type: pr
        is: merged
        merged: $">=($since_stamp)"
    } | merge $query

    search --direction $direction --per-page $per_page --page $page $query
}

# NOTE: merged PRs have created_at and closed_at. Gives the full timespan.
# For a complete timeline, use timeline_url instead. Provides a list of events
#
# TODO: Consider usin $in for full URL.
export def "pr timeline" [repo: string, number: int] {
    base-url
    | http url join $"repos/($repo)/issues/($number)/timeline"
    | fetch all "core"

    # $timeline | get body | insert stamp {|row|
    #     match $row.event {
    #         committed => $row.author.date
    #         reviewed => $row.submitted_at
    #         _ => $row.created_at
    #     }
    # } | select event stamp sha?
}

# Expects a fully qualified timeline URL.
export def "pr timeline-url" [] {
    $in | fetch all "core"
}
