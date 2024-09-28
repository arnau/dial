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
export def "changesets" [start_date: datetime, end_date: datetime, team: string@"team list names"] {
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
export def "timelines" [start_date: datetime, end_date: datetime] {
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
                $row.items | duckdb save -f $"data/timeline/($row.repo).($start_date | format date "%F").($row.max | format date "%F").parquet"
              }
        }
      }
}


# Fetch Jira tickets for the given date range and team members. The result is persisted in `ticket`.
#
# ```nu
# dial tickets 2024-09-23 2024-09-27 red-onions
# ```
export def tickets [start_date: datetime, end_date: datetime, team: string@"team list names"] {
    let emails = team members $team | get email
    let start_date = ($start_date | format date "%F")
    # Adding 1 day to the end date to account for Jira not returning data from the upper date even when <= is used.
    let end_date = seq date --begin-date ($end_date | format date "%F") --days 1 | last
    let filename = $"data/tickets/($team).($start_date).($end_date).parquet"

    let res = jira list fetch $start_date $end_date $emails

    # Soft abort if at least one request failed.
    # TODO: review fail path
    # TODO: Fix when pagination is added
    if ([$res] | where status != 200 | is-not-empty) {
        return $res
    }

    $res
    | get body
    | jira list flatten
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
