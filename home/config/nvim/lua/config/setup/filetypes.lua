return function()
  vim.filetype.add({
    pattern = {
      ['.*/playbooks?/.*.ya?ml'] = 'yaml.ansible',
      ['.*/roles/.*.ya?ml'] = 'yaml.ansible',
      ['.*/handlers/.*.ya?ml'] = 'yaml.ansible',
      ['.*/tasks/.*.ya?ml'] = 'yaml.ansible',
      ['.*/molecule/.*.ya?ml'] = 'yaml.ansible',
      ['.*/host_vars/.*.ya?ml'] = 'yaml.ansible',
      ['.*/group_vars/.*.ya?ml'] = 'yaml.ansible',
      ['.*.lua.j2'] = 'lua.j2',
      ['.*.service.j2'] = 'systemd.j2',
      ['.*.timer.j2'] = 'systemd.j2',
      ['.*.hujson'] = 'hjson',
      ['.*.gohtml'] = 'html',
      ['.*.jet'] = 'html',
      ['.*go.mod'] = 'gomod',
      ['.*.bu'] = 'yaml',
      ['.*.ya?ml.j2'] = 'yaml.j2',
      ['.*.dbml'] = 'dbml',
    },
  })
end
