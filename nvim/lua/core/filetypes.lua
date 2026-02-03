vim.filetype.add({
  filename = {
    ['.gitconfig'] = 'gitconfig',
    ['Brewfile'] = 'ruby',
  },
  pattern = {
    ['gitconfig.*'] = 'gitconfig',
  },
})
