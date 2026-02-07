vim.filetype.add({
  filename = {
    ['.gitconfig'] = 'gitconfig',
    ['Brewfile'] = 'ruby',
    ['COMMIT_EDITMSG'] = 'gitcommit',
    ['MERGE_MSG'] = 'gitcommit',
    ['TAG_EDITMSG'] = 'gitcommit',
    ['SQUASH_MSG'] = 'gitcommit',
  },
  pattern = {
    ['gitconfig.*'] = 'gitconfig',
  },
})
