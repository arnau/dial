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
    | encode new-base64
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

export def "jql team" [start_date: string, end_date: string, members: list<string>] {
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


# Fetches the list of jira tickets done for the given members and timeframe
export def "list fetch" [
    start_date: string
    end_date: string
    members: list<string>
    from: int = 0
    max_results: int = 100
]: nothing -> table {
    let jql = (jql team $start_date $end_date $members)
    let fields = [
        assignee
        created
        creator
        issuetype
        parent
        priority
        reporter
        resolution
        resolutiondate
        status
        summary
        updated
    ]
    let query = {
        jql: $jql
        startAt: $from
        maxResults: $max_results
        fields: ($fields | str join ',')
    }

    base-url
    | http url join "search" -q $query
    | fetch
}


# ```nu
# mark jira list fetch "Customer Data" "2024-08-01" "2024-08-31"
# | mark jira list flatten
# ```
export def "list flatten" []: table -> table {
    $in
    | get issues
    | reject expand self
    | update fields { transpose field value }
    | flatten --all
    | update value {|row|    
        match $row.field {
            "creator" => $row.value.emailAddress?,
            "status" => $row.value.name,
            "assignee" => $row.value.emailAddress?,
            "parent" => $row.value.key?,
            "priority" => $row.value.id?,
            "reporter" => $row.value.emailAddress?,
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
}

# Gets the changelog for the given issue ID from Jira.
export def "changelog fetch" [key: string, from: int = 0]: nothing -> table {
    let query = {startAt: $from}

    base-url
    | http url join $"issue/($key)/changelog" -q $query
    | fetch
    | insert body.key $key
}

# Flattens and slims down the changelog data for the given raw changelog.
export def "changelog flatten" []: table -> table {
    $in
    | select key values
    | flatten --all
    | flatten --all
    | where field == "status"
    | rename --column {emailAddress: email, created: timestamp}

    # TODO
    # | insert from_status { $in.from | map_status }
    # | insert to_status { $in.to | map_status }
    # | select key id from_status to_status emailAddress created
    
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
