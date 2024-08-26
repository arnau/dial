use std assert
use ../http.nu

# From:
# dial github pr merged nushell nushell --since 2024-08-01 --per-page 2
# redacted by hand
const GH_RESPONSE = {headers: {request: [[name, value]; [authorization, "Bearer REDACTED"], [x-github-api-version, "2022-11-28"], [accept, application/vnd.github+json]], response: [[name, value]; [server, github.com], [x-github-media-type, "github.v3; format=json"], [date, "Mon, 26 Aug 2024 08:49:00 GMT"], [x-ratelimit-used, "2"], [x-github-api-version-selected, "2022-11-28"], [x-ratelimit-reset, "1724662187"], [content-type, "application/json; charset=utf-8"], [x-ratelimit-limit, "30"], [x-ratelimit-remaining, "28"], [link, "<https://api.github.com/search/issues?q=repo%3Anushell%2Fnushell+type%3Apr+is%3Amerged+merged%3A%3E%3D2024-08-01&order=desc&per_page=2&page=2>; rel=\"next\", <https://api.github.com/search/issues?q=repo%3Anushell%2Fnushell+type%3Apr+is%3Amerged+merged%3A%3E%3D2024-08-01&order=desc&per_page=2&page=42>; rel=\"last\""], [x-ratelimit-resource, search]]}, body: {total_count: 84, incomplete_results: false, items: [[url, repository_url, labels_url, comments_url, events_url, html_url, id, node_id, number, title, user, labels, state, locked, assignee, assignees, milestone, comments, created_at, updated_at, closed_at, author_association, active_lock_reason, draft, pull_request, body, reactions, timeline_url, performed_via_github_app, state_reason, score]; ["https://api.github.com/repos/nushell/nushell/issues/13690", "https://api.github.com/repos/nushell/nushell", "https://api.github.com/repos/nushell/nushell/issues/13690/labels{/name}", "https://api.github.com/repos/nushell/nushell/issues/13690/comments", "https://api.github.com/repos/nushell/nushell/issues/13690/events", "https://github.com/nushell/nushell/pull/13690", 2485393208, "PR_kwDOCxaBas55XMF2", 13690, "Remove unnecessary sort in `explore` search fn", {login: redacted_string, id: 0, type: User, site_admin: false}, [], closed, false, null, [], null, 0, "2024-08-25T17:44:33Z", "2024-08-25T18:13:07Z", "2024-08-25T18:13:05Z", MEMBER, null, false, {url: "https://api.github.com/repos/nushell/nushell/pulls/13690", html_url: "https://github.com/nushell/nushell/pull/13690", diff_url: "https://github.com/nushell/nushell/pull/13690.diff", patch_url: "https://github.com/nushell/nushell/pull/13690.patch", merged_at: "2024-08-25T18:13:05Z"}, "Noticed when playing with the `stable_sort_primitive` lint that the elements from `enumerate` are already sorted.
", {url: "https://api.github.com/repos/nushell/nushell/issues/13690/reactions", total_count: 0, "+1": 0, "-1": 0, laugh: 0, hooray: 0, confused: 0, heart: 0, rocket: 0, eyes: 0}, "https://api.github.com/repos/nushell/nushell/issues/13690/timeline", null, null, 1.0], ["https://api.github.com/repos/nushell/nushell/issues/13683", "https://api.github.com/repos/nushell/nushell", "https://api.github.com/repos/nushell/nushell/issues/13683/labels{/name}", "https://api.github.com/repos/nushell/nushell/issues/13683/comments", "https://api.github.com/repos/nushell/nushell/issues/13683/events", "https://github.com/nushell/nushell/pull/13683", 2484507365, "PR_kwDOCxaBas55UYl_", 13683, "Fix encode/decode todo's", {login: redacted_string, id: 0, type: User, site_admin: false}, [], closed, false, null, [], {url: "https://api.github.com/repos/nushell/nushell/milestones/42", html_url: "https://github.com/nushell/nushell/milestone/42", labels_url: "https://api.github.com/repos/nushell/nushell/milestones/42/labels", id: 11467431, node_id: "MI_kwDOCxaBas4Arvqn", number: 42, title: "v0.98.0", description: "v0.98.0", creator: {login: redacted_string, id: 0, type: User, site_admin: false}, open_issues: 0, closed_issues: 19, state: open, created_at: "2024-08-20T23:58:22Z", updated_at: "2024-08-25T01:11:22Z", due_on: null, closed_at: null}, 3, "2024-08-24T11:05:53Z", "2024-08-25T01:11:22Z", "2024-08-24T14:02:02Z", CONTRIBUTOR, null, false, {url: "https://api.github.com/repos/nushell/nushell/pulls/13683", html_url: "https://github.com/nushell/nushell/pull/13683", diff_url: "https://github.com/nushell/nushell/pull/13683.diff", patch_url: "https://github.com/nushell/nushell/pull/13683.patch", merged_at: "2024-08-24T14:02:02Z"}, "Mistakes have been made.  I forgot about a bunch of `todo`s in the helper functions.  So, this PR replaces them with proper errors.  It also adds tests for parse-time evaluation, because one `todo` I missed was in a `run_const` function.", {url: "https://api.github.com/repos/nushell/nushell/issues/13683/reactions", total_count: 0, "+1": 0, "-1": 0, laugh: 0, hooray: 0, confused: 0, heart: 0, rocket: 0, eyes: 0}, "https://api.github.com/repos/nushell/nushell/issues/13683/timeline", null, null, 1.0]]}, status: 200}

const GH_RESPONSE_LAST = {headers: {request: [[name, value]; [authorization, "Bearer REDACTED"], [x-github-api-version, "2022-11-28"], [accept, application/vnd.github+json]], response: [[name, value]; [server, github.com], [x-github-media-type, "github.v3; format=json"], [date, "Mon, 26 Aug 2024 08:49:00 GMT"], [x-ratelimit-used, "2"], [x-github-api-version-selected, "2022-11-28"], [x-ratelimit-reset, "1724662187"], [content-type, "application/json; charset=utf-8"], [x-ratelimit-limit, "30"], [x-ratelimit-remaining, "28"], [link, "<https://api.github.com/search/issues?q=repo%3Anushell%2Fnushell+type%3Apr+is%3Amerged+merged%3A%3E%3D2024-08-01&order=desc&per_page=2&page=2>; rel=\"prev\", <https://api.github.com/search/issues?q=repo%3Anushell%2Fnushell+type%3Apr+is%3Amerged+merged%3A%3E%3D2024-08-01&order=desc&per_page=2&page=42>; rel=\"last\""], [x-ratelimit-resource, search]]}, body: {total_count: 84, incomplete_results: false, items: []}, status: 200}


#[test]
def test_http_next [] {
    let expected = "https://api.github.com/search/issues?q=repo%3Anushell%2Fnushell+type%3Apr+is%3Amerged+merged%3A%3E%3D2024-08-01&order=desc&per_page=2&page=2"
    let actual = $GH_RESPONSE | http next
    assert equal $actual $expected
}

#[test]
def test_http_next_missing [] {
    let expected = null
    let actual = $GH_RESPONSE | http next
    assert equal $actual $expected
}


#[test]
def test_http_last [] {
    let expected = "https://api.github.com/search/issues?q=repo%3Anushell%2Fnushell+type%3Apr+is%3Amerged+merged%3A%3E%3D2024-08-01&order=desc&per_page=2&page=42"
    let actual = $GH_RESPONSE | http last
    assert equal $actual $expected
}
