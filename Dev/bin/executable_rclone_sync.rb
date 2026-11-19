#!/usr/bin/env ruby

REMOTE_NAME = 'Strath Onedrive:'
LOCAL_DIR = "#{Dir.home}/Strath Onedrive/"
RESYNC_REQUIRED_STATUS = 7

rclone_normal_opts = ['--progress', '--verbose']
rclone_resync_opts = rclone_normal_opts << '--resync'

system 'rclone', 'bisync', *rclone_normal_opts, REMOTE_NAME, LOCAL_DIR

if $?.exitstatus == RESYNC_REQUIRED_STATUS
  puts 'Resyncing......................'
  system 'rclone', 'bisync', *rclone_resync_opts, REMOTE_NAME, LOCAL_DIR

  echo 'Trying to sync again'
  system 'rclone', 'bisync', *rclone_normal_opts, REMOTE_NAME, LOCAL_DIR
end

puts "Rclone exited with code #{$?.exitstatus}"
