export def pr_statuses [] {
    [open closed all]
}

export def pr_sort [] {
    [created updated popularity long-running]
}

export def pr_direction [] {
    [asc desc]
}

export def gh_ratelimit_resources [] {
    [
        core
        search
        graphql
        integration_manifest
        source_import
        code_scanning_upload
        actions_runner_regitration
        scim
        dependency_snapshots
        audit_log
        audit_log_streaming
        code_search
    ]
}
