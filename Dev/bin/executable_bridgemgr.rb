#!/usr/bin/env ruby

require 'optparse'

ADDITIONAL_HELP = <<~EOF
  \nNOTE:
  The script only works for ethernet interfaces
EOF

def main
  options = {
    bridge: 'br0',
    tap: 'tap0',
    with_tap: false,
    iface: ''
  }

  parser = OptionParser.new do |opts|
    opts.banner = <<~HELP
      Usage: bridgemgr.rb COMMAND [OPTIONS]

      DESCRIPTION:
      This script creates a bridge and attaches an etherent interface to it and optionally a tap interface

      COMMANDS:
          create: creates a bridge.
          remove: removes a bridge.

      OPTIONS:
    HELP

    opts.on('-i IFACE', '--iface IFACE', 'The ethernet interface to attach to the bridge')
    opts.on('-b BRIDGE_NAME', '--bridge BRIDGE_NAME', "The name of the bridge. (Default: #{options[:bridge]})")

    opts.on('--with-tap', "Add or Remove a tap interface to the bridge. (Default: #{options[:with_tap]})") do
      options[:with_tap] = true
    end

    opts.on('-t TAP', '--tap TAP', "The name of tap interface to attach to the bridge. (Default: #{options[:tap]})")

    opts.on('-h', '--help', 'Print this help message') do
      puts opts
      puts ADDITIONAL_HELP
      exit
    end
  end
  parser.parse!(into: options)

  command = ARGV.shift

  abort "No command given. Use 'bridgemgr.rb --help' for more information" if command.nil? or command.empty?

  case command
  when 'create'
    create_bridge(options)
  when 'remove'
    remove_bridge(options)
  else
    abort "Unknown command '#{command}'. Use 'bridgemgr.rb --help' for more information"
  end
end

def create_bridge(options)
  abort 'This script requires root privileges to run' unless Process.euid.zero?

  all_ifaces = get_ifaces

  iface = if options[:iface].empty?
            get_choice_from_terminal(all_ifaces.filter_ethernet,
                                     'Select an ethernet interface to connect to the bridge')
          else
            options[:iface]
          end

  abort 'Could not find any ethernet interfaces to connect to the bridge.' if iface.nil? or iface.empty?
  abort "Interface #{iface} does not exist" unless all_ifaces.include?(iface)
  unless iface.is_ethernet?
    abort "Interface '#{iface}' is not an ethernet interface. Only ethernet interfaces are supported."
  end

  bridge = options[:bridge]
  bridge_con = "bridge_#{bridge}"
  iface_to_bridge_con = "#{bridge}_#{iface}"

  puts "Using ethernet interface: #{iface}"

  nmcli_con = nmcli_con_for_iface(iface)
  if nmcli_con
    puts "Deleting existing nmcli connection associated with #{iface}: '#{nmcli_con}'"
    del_nmcli_con nmcli_con
  end

  if nmcli_con_exists?(bridge_con)
    puts "Deleting existing nmcli connection for bridge: '#{bridge_con}'"
    del_nmcli_con bridge_con
  end

  if nmcli_con_exists?(iface_to_bridge_con)
    puts "Deleting existing nmcli connection for interface to bridge: '#{iface_to_bridge_con}'"
    del_nmcli_con iface_to_bridge_con
  end

  puts "\nCreating Bridge #{bridge}......."
  system "nmcli con add type bridge con-name #{bridge_con} ifname #{bridge}"

  puts "Attaching #{iface} to #{bridge}"
  system "nmcli con add type bridge-slave con-name #{iface_to_bridge_con} ifname #{iface} master #{bridge_con}"

  if options[:with_tap]
    tap = options[:tap]
    puts ''

    unless all_ifaces.include?(tap)
      puts "Creating tap interface #{tap}......"
      system "ip tuntap add #{tap} mode tap"
      if $?.success?
        puts "Tap interface '#{tap}' created successfully. Make sure to pass '--with-tap' again when removing the bridge to delete this #{tap} interface also."
      end
    end

    puts "Attaching #{tap} to #{bridge}"
    system "ip link set dev #{tap} master #{bridge}"
    system "ip link set dev #{tap} up"
    puts "Tap interface '#{tap}' successfully attached to the bridge '#{bridge}'." if $?.success?

  end

  puts "\nBringing bridge up..................."
  system "nmcli con up #{iface_to_bridge_con}"

  puts "\nAttempting to obtain an IP address for #{bridge}. Press Ctrl-C to abort........"
  system "dhclient -r #{bridge}"
  system "dhclient -v #{bridge}"
end

def remove_bridge(options)
  abort 'This script requires root privileges to run' unless Process.euid.zero?

  all_ifaces = get_ifaces

  iface = if options[:iface].empty?
            get_choice_from_terminal(all_ifaces.filter_ethernet,
                                     'Select the ethernet interface that was connected to the bridge')
          else
            abort "Interface '#{options[:iface]}' does not exists" unless all_ifaces.include?(options[:iface])

            unless iface.is_ethernet?
              abort "Interface '#{iface}' is not an ethernet interface. Only ethernet interfaces are supported."
            end

            options[:iface]
          end

  bridge = options[:bridge]
  bridge_con = "bridge_#{bridge}"
  bridge_exists = all_ifaces.include?(bridge)
  iface_to_bridge_con = "#{bridge}_#{iface}"

  if !iface.nil? and !iface.empty? and nmcli_con_exists?(iface_to_bridge_con)
    puts "Deleting connection of '#{iface}' to the bridge '#{bridge}"
    system "nmcli con del #{iface_to_bridge_con}"
  end

  if bridge_exists and nmcli_con_exists?(bridge_con)
    puts "Deleting '#{bridge}'........"
    system "nmcli con del #{bridge_con}"
  end

  if options[:with_tap] and all_ifaces.include?(options[:tap])
    puts "Deleting '#{options[:tap]}'............."
    system "ip link del #{options[:tap]}"
    puts "Tap interface '#{options[:tap]}' successfully deleted" if $?.success?
  end

  return unless !iface.nil? and !iface.empty?

  puts "\nAttempting to restore connection on #{iface}. Press Ctrl-C to abort"
  system "nmcli con add type ethernet ifname #{iface}"
end

def get_ifaces
  require 'socket'

  Socket.getifaddrs.map(&:name).uniq
end

def nmcli_con_exists?(name)
  nmcli_con = `nmcli con show | grep #{name}`

  !nmcli_con.empty?
end

def del_nmcli_con(name)
  system "nmcli con del #{name}"
end

def nmcli_con_for_iface(iface)
  `nmcli con show | grep #{iface}`.split(' ')[-3]
end

def get_choice_from_terminal(choices, message = 'Select a choice', allow_empty = false)
  return '' if choices.nil? or choices.empty?
  return choices[0] if choices.length == 1

  choices.each_with_index do |choice, i|
    puts "#{i + 1}. #{choice}"
  end

  print "#{message}: "
  input_ok = false

  until input_ok
    indexStr = gets.chomp

    if indexStr.empty?
      return '' if allow_empty

      print 'Enter a number corresponding to your choice: '
      next
    end

    index = begin
      index = Integer(indexStr)
    rescue ArgumentError
      print 'Enter a correct number: '
      next
    end

    if index > choices.length or index < 1
      print "Enter a number between 1 and #{choices.length}: "
      next
    end

    input_ok = true
  end

  choices[index - 1]
end

class Array
  def filter_ethernet
    select { |name| name.match?(/\A(enp[0-9].+|eth[0-9]{1,2})\z/) }
  end
end

class String
  def is_ethernet?
    match?(/\A(enp[0-9].+|eth[0-9]{1,2})\z/)
  end
end

main
