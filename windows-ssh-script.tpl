add-content -path c:/users/Matt.Bleezarde/.ssh/config -value @'

Host ${hostname}
  hostName ${hostname}
  user ${user}
  identityFile ${identityfile}
'@