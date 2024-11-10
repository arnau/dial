# Interactions with Jira
#
# Depends on three environment variables:
#
# - `JIRA_USERNAME`. The Jira Cloud user email.
# - `JIRA_TOKEN`. The Jira Cloud bare token. Automatically attempts to dereference  1Password references, otherwise use the plain value.
# - `JIRA_BASEURL`. The fully qualified URL of the Jira Cloud instance. E.g. `https://dialmetrics.atlassian.net`.

use ./error.nu *
use token.nu
use http.nu
use config.nu *


def base-url [] {
    let baseurl = try-env JIRA_BASEURL

    $"($baseurl)/rest/api/3/"
}

# Composes a token for the Jira REST API.
def credentials [] {
    let username = try-env JIRA_USERNAME
    let token = try-env JIRA_TOKEN

    $"($username):(token read $token)"
    | encode base64
}


# Requests someting from the Jira API.
export def "fetch" []: [string -> table] {
    let url = $in
    let headers = {
        Accept: "application/json"
        Authorization: $"Basic (credentials)"
    }

    http get --full --allow-errors --headers $headers $url 
}

# Fetches a list page and provides the result and the URL to the next page.
#
# To be used with `generate`. Most likely you want to use `fetch all`
def "fetch page" [] {
    let input = $in
    let url = $input.url?

    if ($url | is-not-empty) {
        let res = $url | fetch

        if $res.status != 200 {
            return {
                out: {status: $res.status url: $url eror: $res.body}
                next: null
            }
        }

        let out = {
            status: $res.status
            url: $url
            next_url: ($res.body | get nextPage?)            
            data: $res.body.values
        }

        {out: $out, next: {url: $out.next_url}}
    }
}

# Fetches all records of a paginated resource.
#
# See also `search all` for JQL paginated queries.
export def "fetch all" [] {
    let url = $in
    let input = {
        url: $url
    }

    generate {fetch page} $input
}

# Fetches a list page and provides the result and the URL to the next page.
#
# To be used with `generate`. Most likely you want to use `search all`
def "search page" [] {
    let input = $in
    let url = $input.url?
    let query = $input.query?
    let count = $input.count?

    if ($url | is-not-empty) {
        let res = $url | fetch

        if $res.status != 200 {
            return {
                out: {status: $res.status url: $url eror: $res.body}
                next: null
            }
        }

        let data = $res.body.issues
        let next_count = $count + ($data | length)
        let next_query = $query | merge {
            startAt: $res.body.startAt
            maxResults: $res.body.maxResults
        }

        let next_url = if ($next_count < $res.body.total) {
            base-url | http url join "search" -q $next_query
        } else { null }

        let out = {
            status: $res.status
            url: $url
            next_url: $next_url
            data: $data
        }

        {
            out: $out
            next: {
                url: $out.next_url
                count: $next_count
                query: $next_query
            }
        }
    }
}

# Fetches all pages result of a JQL search.
export def "search all" [query: record] {
    let url = base-url | http url join "search" -q $query
    let input = {
        url: $url
        query: $query
        count: 0
    }

    generate {search page} $input
}

# Generates a JQL query to search for all closed (done) tickets for the given date range and list of members.
export def "jql closed-tickets" [start_date: string, end_date: string, members: list<string>] {
    let members = $members | each { $"'($in)'"} | str join ", "

    [
        $"assignee in \(($members)\)"
        "Status = Done"
        $"resolutiondate >= ($start_date)"
        $"resolutiondate <= ($end_date)"
    ]
    | str join " AND "
    | $in + " ORDER BY Rank ASC"
}


# Fetches the list of jira tickets done for the given date range and email list.
#
# ```nu
# jira tickets fetch 2024-08-01 2024-08-31 (dial team members red-onions | get email)
# ```
export def "ticket fetch" [
    start_date: datetime
    end_date: datetime
    emails: list<string>
    --from: int = 0
    --max_results: int = 100
]: nothing -> table {
    let start_date = ($start_date | format date "%F")
    # WARN: Adding 1 day to the end date to account for Jira not returning data from the upper date even when <= is used.
    let end_date = seq date --begin-date ($end_date | format date "%F") --days 1 | last
    let jql = (jql closed-tickets $start_date $end_date $emails)
    let fields = [
        assignee
        created
        issuetype
        parent
        priority
        resolution
        resolutiondate
        status
        summary
    ]
    let query = {
        jql: $jql
        startAt: $from
        maxResults: $max_results
        fields: ($fields | str join ',')
    }

    search all $query
}

# Translates a Jira search response into the dial ticket data model.
export def "ticket normalise" []: table -> table {
    let data = $in | flatten

    if ($data | compact | is-empty) { return [] }

    $data
    | reject expand self
    | update fields { transpose field value }
    | flatten --all
    | update value {|row|    
        match $row.field {
            "status" => $row.value.name,
            "assignee" => $row.value.emailAddress?,
            "parent" => $row.value.key?,
            "priority" => $row.value.id?,
            "issuetype" => $row.value.name?,
            "resolution" => $row.value.name?,
            _ => $row.value,
        }
      }
    | select id key field value
    | group-by --to-table key
    | update items {
        $in
        | select field value
        | transpose -ir
      }
    | rename key
    | flatten --all
    | rename --column {
          issuetype: type
          created: creation_date
          resolutiondate: resolution_date
      }
    | insert source "jira"
}

# Gets the changelog for the given issue ID from Jira.
export def "changelog fetch" [key: string, from: int = 0, max_results: int = 100]: nothing -> table {
    let query = {startAt: $from, maxResults: $max_results}

    base-url
    | http url join $"issue/($key)/changelog" -q $query
    | fetch all
    | insert data.key $key
}

def normalise-status [] {
    match $in {
        # "To Do" => "to-do"
        # "In Progress" => "in-progress"
        # "Done" => "done"
        $s => ($s | str kebab-case)
    }
}

# Flattens and slims down the changelog data for the given raw changelog.
export def "changelog flatten" []: table -> table {
    $in
    | update author { get emailAddress }
    | flatten --all
    | where field == "status"
    | reject fieldId fieldtype from to field
    | rename --column {created: timestamp, fromString: start_status, toString: end_status, author: actor} 
    | insert source "jira"
    | update start_status { normalise-status }
    | update end_status { normalise-status }
    | select id key source timestamp actor start_status end_status
}


export def main [] {
    let commands = (
      help modules
      | select name commands
      | flatten --all
      | get commands_name
      | parse "jira {name}"
    )

    $commands
    | join (help commands) name
    | select name usage
}
