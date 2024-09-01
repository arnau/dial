# Managing data fetched from sources such as GitHub.
use config.nu *
use github.nu
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




# Fetches and stores data about the GitHub Pull Requests merged since the given date
# and stores it in the merged bucket.
export def "merged" [since: datetime, team: string@"team list"] {
    let repos = team repos $team | get name
    let start_date = ($since | format date "%F")
    let end_date = (date now | format date "%F")
    let filename = $"data/merged/($team).($start_date).($end_date).parquet"

    github pr list merged -s $since ...$repos
    | get data.items
    | flatten
    | select number repository_url url timeline_url title created_at updated_at closed_at user.login
    | rename --column {"user.login": "creator"}
    | insert repo {|row|
          $row.repository_url
          | parse --regex '(?<repo>[^\/]+\/[^\/]+)$'
          | get repo.0
      }
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

export def "timelines" [since: datetime] {
    duckdb open data/merged/*.parquet
    | update closed_at { into datetime }
    | where closed_at >= $since
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
                $row.items | duckdb save -f $"data/timeline/($row.repo).($since | format date "%F").($row.max | format date "%F").parquet"
              }
        }
      }
}
