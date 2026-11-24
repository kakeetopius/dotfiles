#!/usr/bin/env ruby

syncs = {
  'Strath Onedrive:': "#{Dir.home}/Strath Onedrive",
  'OneDrive Personal:/Documents': "#{Dir.home}/Documents/Docs"
}

RESYNC_REQUIRED_STATUS = 7
rclone_normal_opts = ['--progress', '--verbose']
rclone_resync_opts = rclone_normal_opts + ['--resync-mode=newer']

syncs.each do |remote, local|
  puts "### Syncing remote #{remote} ###"

  system 'rclone', 'bisync', *rclone_normal_opts, remote.to_s, local

  if $?.exitstatus == RESYNC_REQUIRED_STATUS
    puts 'Resyncing......................'
    system 'rclone', 'bisync', *rclone_resync_opts, remote.to_s, local

    puts 'Trying to sync again'
    system 'rclone', 'bisync', *rclone_normal_opts, remote.to_s, local
  end

  puts "Rclone exited with code #{$?.exitstatus}"
end
