return {
    'nvim-neo-tree/neo-tree.nvim',
    branch = 'v3.x',
    dependencies = {
        'nvim-lua/plenary.nvim',
        'nvim-tree/nvim-web-devicons',
        'MunifTanjim/nui.nvim',
    },
    config = function()
        require('neo-tree').setup({
            filesystem = {
                follow_current_file = {
                    enabled = true,
                    leave_dirs_open = false,
                },
                enable_git_status = true,
                hijack_netrw_behavior = 'open_current',
                filtered_items = {
                    hide_dotfiles = false,
                    hide_gitignored = false,
                    show_hidden_count = true,
                }
            },
            window = {
                position = 'right',
                width = 48,
            },
        })
    end,
}
