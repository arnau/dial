# Managing data fetched from sources such as GitHub.
use config.nu *
use github.nu
use jira.nu
use duckdb.nu

const allowlist_events = [
    assigned        
    closed
    commented
    committed
    convert_to_draft
    merged
    ready_for_review
    renamed
    reopened
    review_dismissed
    review_requested
    review_request_removed
    reviewed
    unassigned
]

# Fetches merged GitHub Pull Request for the team organisations for the given date
# range. The result is persisted in `changeset`.
export def "changeset fetch" [start_date: datetime, end_date: datetime, team: string@"team list names"] {
    let orgs = team orgs $team
    let start_date = ($start_date | format date "%F")
    let end_date = ($start_date | format date "%F")
    let filename = $"data/changeset/($orgs | str join ".").($start_date).($end_date).parquet"

    let res = github pr list merged -s $start_date {org: $orgs}

    # Soft abort if at least one request failed.
    # TODO: review fail path
    if ($res | where status != 200 | is-not-empty) {
        return $res
    }

    $res
    | get data.items
    | github pr list normalise
    | tee { if ($in | is-not-empty) { $in | duckdb save -f $filename } }
    | do {
          let items = $in

          {
              filename: $filename
              count: ($items | length)
              start_date: $start_date
              end_date: $end_date
          }
      }
}

# Fetches the timelines for any changeset stored for the given date range.
# The result is persisted in `changeset_timeline`.
export def "changeset timeline fetch" [start_date: datetime, end_date: datetime] {
    duckdb open data/changeset/*.parquet
    | update closed_at { into datetime }
    | where closed_at >= $start_date
    | where closed_at <= $end_date
    | par-each {|row|
          $row.timeline_url
          | github pr timeline-url
          | get data
          | flatten
          | insert number { $row.number }
          | insert repo { $row.repo }
      }
    | flatten
    | collect
    | where { $in.event in $allowlist_events }
    | upsert actor {|row|
          match $row.event {
              committed => $row.author.email
              commented | reviewed => $row.user.login
              _ => $row.actor.login
          }
      }
    | insert timestamp {|row|
          match $row.event {
              committed => $row.author.date
              reviewed => $row.submitted_at
              _ => $row.created_at
          }
      }
    | select number repo timestamp event actor url?
    | do {
        if ($in | is-not-empty) {
            let groups = $in | group-by --to-table repo
            | insert max {|row| $row.items.timestamp | math max }

            $groups
            | insert repo {|row| $row.group | str replace "/" "+" }
            | each {|row|
                $row.items | duckdb save -f $"data/changeset_timeline/($row.repo).($start_date | format date "%F").($row.max | format date "%F").parquet"
              }
        }
      }
}


# Fetch Jira tickets for the given date range and team members. The result is persisted in `ticket`.
#
# ```nu
# dial ticket fetch 2024-09-23 2024-09-27 red-onions
# ```
export def "ticket fetch" [start_date: datetime, end_date: datetime, team: string@"team list names"] {
    let emails = team members $team | get email
    let start_date_s = $start_date | format date "%F"
    let end_date_s = $end_date | format date "%F"
    let filename = $"data/ticket/($team).($start_date_s).($end_date_s).parquet"

    let res = jira ticket fetch $start_date $end_date $emails

    $res
    | where status == 200
    | get data?
    | flatten
    | jira ticket flatten
    | tee { if ($in | is-not-empty) { $in | duckdb save -f $filename } }
    | do {
          let items = $in

          {
              filename: $filename
              count: ($items | length)
              start_date: $start_date
              end_date: $end_date
              errors: ($res | where status != 200)
          }
      }
}


export def "ticket timeline fetch" [start_date: datetime, end_date: datetime] {
    duckdb open data/ticket/*.parquet
    | update resolution_date { into datetime }
    | where resolution_date >= $start_date and resolution_date <= $end_date
    | par-each {|row|
          let res = jira changelog fetch $row.key

          if ($res | where status != 200 | is-empty) {
              $res
              | get data?
              | flatten
              | jira changelog flatten
              | duckdb save -f $"data/ticket_timeline/($row.key).parquet"
          } else {
              fail $"Failed to fetch ($row.key)"
          }
      }
}
