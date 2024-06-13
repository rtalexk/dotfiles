if true then
  return {}
end

return {
  {
    'pwntester/octo.nvim',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-telescope/telescope.nvim',
      'nvim-tree/nvim-web-devicons',
    },
    config = function()
      require('octo').setup {
        -- use local files on right side of reviews
        use_local_fs = false,

        -- shows a list of builtin actions when no action is provided
        enable_builtin = false,

        -- order to try remotes
        default_remote = { 'upstream', 'origin' },

        -- default merge method which should be used when calling `Octo pr merge`, could be `commit`, `rebase` or `squash`
        default_merge_method = 'commit',

        -- SSH aliases. e.g. `ssh_aliases = {["github.com-work"] = "github.com"}`
        ssh_aliases = {},

        -- or "fzf-lua"
        picker = 'telescope',

        picker_config = {
          -- only used by "fzf-lua" picker for now
          use_emojis = false,

          -- mappings for the pickers
          mappings = {
            open_in_browser = { lhs = '<C-b>', desc = 'open issue in browser' },
            copy_url = { lhs = '<C-y>', desc = 'copy url to system clipboard' },
            checkout_pr = { lhs = '<C-o>', desc = 'checkout pull request' },
            merge_pr = { lhs = '<C-r>', desc = 'merge pull request' },
          },
        },

        -- comment marker
        comment_con = '▎',

        -- outdated indicator
        outdated_ico = '󰅒 ',

        -- resolved indicator
        resolved_ico = ' ',

        -- marker for user reactions
        reaction_viewer_hin_icon = ' ',

        -- user icon
        use_icon = ' ',

        -- timeline marker
        timeline_arker = ' ',

        -- timeline indentation
        timeline_inden = '2',

        -- bubble delimiter
        right_bubbe_delimiter = '',

        -- bubble delimiter
        left_bubbl_delimiter = '',

        -- GitHub Enterprise host
        github_hostname = '',

        -- number or lines around commented lines
        snippet_context_lines = 4,

        -- Command to use when calling Github CLI
        gh_cmd = 'gh',

        -- extra environment variables to pass on to GitHub CLI, can be a table or function returning a table
        gh_env = {},

        -- timeout for requests between the remote server
        timeout = 5000,

        -- use projects v2 for the `Octo card ...` command by default. Both legacy and v2 commands are available under `Octo cardlegacy ...` and `Octo cardv2 ...` respectively.
        default_to_projects_v2 = false,

        ui = {
          -- show "modified" marks on the sign column
          use_signcolumn = false,

          -- show "modified" marks on the status column
          use_signstatus = true,
        },

        issues = {
          -- criteria to sort results of `Octo issue list`
          order_by = {

            -- either COMMENTS, CREATED_AT or UPDATED_AT (https://docs.github.com/en/graphql/reference/enums#issueorderfield)
            field = 'CREATED_AT',

            -- either DESC or ASC (https://docs.github.com/en/graphql/reference/enums#orderdirection)
            direction = 'DESC',
          },
        },

        pull_requests = {
          -- criteria to sort the results of `Octo pr list`
          order_by = {
            -- either COMMENTS, CREATED_AT or UPDATED_AT (https://docs.github.com/en/graphql/reference/enums#issueorderfield)
            field = 'CREATED_AT',

            -- either DESC or ASC (https://docs.github.com/en/graphql/reference/enums#orderdirection)
            direction = 'DESC',
          },
          --
          -- always give prompt to select base remote repo when creating PRs
          always_select_remote_on_create = false,
        },

        file_panel = {
          -- changed files panel rows
          size = 10,

          -- use web-devicons in file panel (if false, nvim-web-devicons does not need to be installed)
          use_icons = true,
        },

        -- used for highlight groups (see Colors section below)
        colors = {
          white = '#ffffff',
          grey = '#2A354C',
          black = '#000000',
          red = '#fdb8c0',
          dark_red = '#da3633',
          green = '#acf2bd',
          dark_green = '#238636',
          yellow = '#d3c846',
          dark_yellow = '#735c0f',
          blue = '#58A6FF',
          dark_blue = '#0366d6',
          purple = '#6f42c1',
        },

        -- disable default mappings if true, but will still adapt user mappings
        mappings_disable_default = false,

        mappings = {
          issue = {
            close_issue = { lhs = '<space>ic', desc = 'close issue' },
            reopen_issue = { lhs = '<space>io', desc = 'reopen issue' },
            list_issues = { lhs = '<space>il', desc = 'list open issues on same repo' },

            reload = { lhs = '<C-r>', desc = 'reload issue' },
            open_in_browser = { lhs = '<C-b>', desc = 'open issue in browser' },
            copy_url = { lhs = '<C-y>', desc = 'copy url to system clipboard' },

            add_assignee = { lhs = '<space>iaa', desc = 'add assignee' },
            remove_assignee = { lhs = '<space>iad', desc = 'remove assignee' },

            create_label = { lhs = '<space>ilc', desc = 'create label' },
            add_label = { lhs = '<space>ila', desc = 'add label' },
            remove_label = { lhs = '<space>ild', desc = 'remove label' },

            goto_issue = { lhs = '<space>igi', desc = 'navigate to a local repo issue' },

            add_comment = { lhs = '<space>ica', desc = 'add comment' },
            delete_comment = { lhs = '<space>icd', desc = 'delete comment' },
            next_comment = { lhs = ']C', desc = 'go to next comment' },
            prev_comment = { lhs = '[C', desc = 'go to previous comment' },

            react_hooray = { lhs = '<space>irp', desc = 'Toggle 🎉 reaction' },
            react_heart = { lhs = '<space>irh', desc = 'Toggle ❤️ reaction' },
            react_eyes = { lhs = '<space>ire', desc = 'Toggle 👀 reaction' },
            react_thumbs_up = { lhs = '<space>ir+', desc = 'Toggle 👍 reaction' },
            react_thumbs_down = { lhs = '<space>ir-', desc = 'Toggle 👎 reaction' },
            react_rocket = { lhs = '<space>irr', desc = 'Toggle 🚀 reaction' },
            react_laugh = { lhs = '<space>irl', desc = 'Toggle 😄 reaction' },
            react_confused = { lhs = '<space>irc', desc = 'Toggle 😕 reaction' },
          },

          pull_request = {
            checkout_pr = { lhs = '<space>po', desc = 'checkout PR' },

            merge_pr = { lhs = '<space>pmm', desc = 'merge commit PR' },
            squash_and_merge_pr = { lhs = '<space>pms', desc = 'squash and merge PR' },
            rebase_and_merge_pr = { lhs = '<space>pmr', desc = 'rebase and merge PR' },

            list_commits = { lhs = '<space>pC', desc = 'list PR commits' },
            list_changed_files = { lhs = '<space>pf', desc = 'list PR changed files' },
            show_pr_diff = { lhs = '<space>pd', desc = 'show PR diff' },

            close_issue = { lhs = '<space>pc', desc = 'close PR' },
            reopen_issue = { lhs = '<space>po', desc = 'reopen PR' },
            list_issues = { lhs = '<space>il', desc = 'list open issues on same repo' },
            reload = { lhs = '<C-r>', desc = 'reload PR' },
            open_in_browser = { lhs = '<C-b>', desc = 'open PR in browser' },
            copy_url = { lhs = '<C-y>', desc = 'copy url to system clipboard' },
            goto_file = { lhs = 'gf', desc = 'go to file' },

            add_assignee = { lhs = '<space>paa', desc = 'add assignee' },
            remove_assignee = { lhs = '<space>pad', desc = 'remove assignee' },

            create_label = { lhs = '<space>plc', desc = 'create label' },
            add_label = { lhs = '<space>pla', desc = 'add label' },
            remove_label = { lhs = '<space>pld', desc = 'remove label' },

            goto_issue = { lhs = '<space>pgi', desc = 'navigate to a local repo issue' },

            add_comment = { lhs = '<space>pca', desc = 'add comment' },
            delete_comment = { lhs = '<space>pcd', desc = 'delete comment' },
            next_comment = { lhs = ']C', desc = 'go to next comment' },
            prev_comment = { lhs = '[C', desc = 'go to previous comment' },

            react_hooray = { lhs = '<space>prp', desc = 'Toggle 🎉 reaction' },
            react_heart = { lhs = '<space>prh', desc = 'Toggle ❤️ reaction' },
            react_eyes = { lhs = '<space>pre', desc = 'Toggle 👀 reaction' },
            react_thumbs_up = { lhs = '<space>pr+', desc = 'Toggle 👍 reaction' },
            react_thumbs_down = { lhs = '<space>pr-', desc = 'Toggle 👎 reaction' },
            react_rocket = { lhs = '<space>prr', desc = 'Toggle 🚀 reaction' },
            react_laugh = { lhs = '<space>prl', desc = 'Toggle 😄 reaction' },
            react_confused = { lhs = '<space>prc', desc = 'Toggle 😕 reaction' },

            review_start = { lhs = '<space>pvs', desc = 'start a review for the current PR' },
            review_resume = { lhs = '<space>pvr', desc = 'resume a pending review for the current PR' },
            add_reviewer = { lhs = '<space>pva', desc = 'add reviewer' },
            remove_reviewer = { lhs = '<space>pvd', desc = 'remove reviewer request' },
          },
          review_thread = {
            goto_issue = { lhs = '<space>pgi', desc = 'navigate to a local repo issue' },

            add_comment = { lhs = '<space>pca', desc = 'add comment' },
            add_suggestion = { lhs = '<space>psa', desc = 'add suggestion' },
            delete_comment = { lhs = '<space>pcd', desc = 'delete comment' },

            next_comment = { lhs = ']C', desc = 'go to next comment' },
            prev_comment = { lhs = '[C', desc = 'go to previous comment' },
            select_next_entry = { lhs = ']q', desc = 'move to previous changed file' },
            select_prev_entry = { lhs = '[q', desc = 'move to next changed file' },
            select_first_entry = { lhs = '[Q', desc = 'move to first changed file' },
            select_last_entry = { lhs = ']Q', desc = 'move to last changed file' },

            close_review_tab = { lhs = '<C-c>', desc = 'close review tab' },

            react_hooray = { lhs = '<space>rp', desc = 'Toggle 🎉 reaction' },
            react_heart = { lhs = '<space>rh', desc = 'Toggle ❤️ reaction' },
            react_eyes = { lhs = '<space>re', desc = 'Toggle 👀 reaction' },
            react_thumbs_up = { lhs = '<space>r+', desc = 'Toggle 👍 reaction' },
            react_thumbs_down = { lhs = '<space>r-', desc = 'Toggle 👎 reaction' },
            react_rocket = { lhs = '<space>rr', desc = 'Toggle 🚀 reaction' },
            react_laugh = { lhs = '<space>rl', desc = 'Toggle 😄 reaction' },
            react_confused = { lhs = '<space>rc', desc = 'Toggle 😕 reaction' },
          },
          submit_win = {
            approve_review = { lhs = '<C-a>', desc = 'approve review' },
            comment_review = { lhs = '<C-m>', desc = 'comment review' },
            request_changes = { lhs = '<C-r>', desc = 'request changes review' },
            close_review_tab = { lhs = '<C-c>', desc = 'close review tab' },
          },
          review_diff = {
            submit_review = { lhs = '<leader>vs', desc = 'submit review' },
            discard_review = { lhs = '<leader>vd', desc = 'discard review' },
            add_review_comment = { lhs = '<space>ca', desc = 'add a new review comment' },
            add_review_suggestion = { lhs = '<space>sa', desc = 'add a new review suggestion' },
            focus_files = { lhs = '<leader>E', desc = 'move focus to changed file panel' },
            toggle_files = { lhs = '<leader>b', desc = 'hide/show changed files panel' },
            next_thread = { lhs = ']T', desc = 'move to next thread' },
            prev_thread = { lhs = '[T', desc = 'move to previous thread' },
            select_next_entry = { lhs = ']q', desc = 'move to previous changed file' },
            select_prev_entry = { lhs = '[q', desc = 'move to next changed file' },
            select_first_entry = { lhs = '[Q', desc = 'move to first changed file' },
            select_last_entry = { lhs = ']Q', desc = 'move to last changed file' },
            close_review_tab = { lhs = '<C-c>', desc = 'close review tab' },
            toggle_viewed = { lhs = '<leader><space>', desc = 'toggle viewer viewed state' },
            goto_file = { lhs = 'gf', desc = 'go to file' },
          },
          file_panel = {
            submit_review = { lhs = '<leader>vs', desc = 'submit review' },
            discard_review = { lhs = '<leader>vd', desc = 'discard review' },
            next_entry = { lhs = 'j', desc = 'move to next changed file' },
            prev_entry = { lhs = 'k', desc = 'move to previous changed file' },
            select_entry = { lhs = '<cr>', desc = 'show selected changed file diffs' },
            refresh_files = { lhs = 'R', desc = 'refresh changed files panel' },
            focus_files = { lhs = '<leader>e', desc = 'move focus to changed file panel' },
            toggle_files = { lhs = '<leader>b', desc = 'hide/show changed files panel' },
            select_next_entry = { lhs = ']q', desc = 'move to previous changed file' },
            select_prev_entry = { lhs = '[q', desc = 'move to next changed file' },
            select_first_entry = { lhs = '[Q', desc = 'move to first changed file' },
            select_last_entry = { lhs = ']Q', desc = 'move to last changed file' },
            close_review_tab = { lhs = '<C-c>', desc = 'close review tab' },
            toggle_viewed = { lhs = '<leader><space>', desc = 'toggle viewer viewed state' },
          },
        },
      }
    end,
  },
}
