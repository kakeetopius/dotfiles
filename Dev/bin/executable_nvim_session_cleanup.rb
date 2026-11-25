#!/usr/bin/env ruby

require 'fileutils'

# This script deletes neovim sessions managed by the plugin rmagatti/auto-session that have not been used for a week.

MAX_AGE = 60 * 60 * 24 * 7 # 1 weeks

def main
  session_dir = Dir.new("#{Dir.home}/.local/share/nvim/sessions")

  exit unless Dir.exist?(session_dir)

  deleted = 0
  session_dir.each_child do |file|
    file_name = Pathname.new(session_dir) + file

    next unless File.file?(file_name)
    next unless is_stale?(file_name)

    puts "Deleting #{file_name}"
    FileUtils.rm_f file_name
    deleted += 1
  end

  puts 'All sessions are not stale. Nothing Deleted' if deleted == 0
end

def is_stale?(file_path)
  file_stat = File.stat(file_path)
  return true if Time.now - file_stat.atime > MAX_AGE

  false
end

main
