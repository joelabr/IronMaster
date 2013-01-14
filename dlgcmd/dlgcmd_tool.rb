require 'json'
require 'optparse'

require_relative 'DlgCmdFile.rb'
require_relative 'DlgCmdEntry.rb'
require_relative 'DlgIdxFile.rb'

module IronMaster
  def self.merge_dlgcmd(dlgcmd_path, dlgidx_path, input, binary = false)
    ext = "*.json"
    ext = "*.bin" if (binary)

    if (Dir.exists?(input))
      dlgcmd = DlgCmdFile.new

      Dir.chdir(input) do
        Dir.glob(ext) do |filename|
          if (binary)
            dlgcmd.entries << File.open(filename, "rb:ASCII-8BIT") { |file| DlgCmdEntry.from_file(file) }
          else
            dlgcmd.entries << File.open(filename, "r:UTF-8") { |file| DlgCmdEntry.from_json(file.read) }
          end
        end
      end

      dlgcmd.sort_by { |entry| entry.header.label }

      dlgidx = DlgIdxFile.from_dlgcmd(dlgcmd)

      File.open(dlgcmd_path, "wb:ASCII-8BIT") { |file| dlgcmd.to_file(file) }
      File.open(dlgidx_path, "wb:ASCII-8BIT") { |file| dlgidx.to_file(file) }
    else
      puts "#{input} is not a directory!"
    end
  end

  def self.split_dlgcmd(dlgcmd_path, dlgidx_path, output, binary = false)
    dlgcmd_path = File.absolute_path(dlgcmd_path)
    dlgidx = File.open(dlgidx_path, "rb:ASCII-8BIT") { |file| DlgIdxFile.from_file(file) }

    Dir.mkdir(output) if (!Dir.exists?(output))
    Dir.chdir(output) do
      File.open(dlgcmd_path, "rb:ASCII-8BIT") do |file|
        dlgidx.entries.each do |entry|
          file.pos = entry.offset

          data = file.read(entry.header_size + entry.data_length)

          id, label = data.unpack("I>Z*")
          filename = "#{sprintf("%04X", id)}_#{label}"
          
          File.open("#{filename}.bin", "wb:ASCII-8BIT") { |file| file.write(data) }

          if (!binary)
            dlgcmd_entry = File.open("#{filename}.bin", "rb:ASCII-8BIT") { |file| DlgCmdEntry.from_file(file) }

            File.delete("#{filename}.bin")
            File.open("#{filename}.json", "w:UTF-8") { |file| file.write(JSON.pretty_generate(dlgcmd_entry)) }
          end
        end
      end
    end
  end

  binary      = false
  dlgcmd_path = "dlgcmd.bin"
  dlgidx_path = "dlgidx.bin"
  folder      = "."
  split       = false

  option_parser = OptionParser.new("Usage: dlgcmd_tool.rb [options]") do |opts|
    opts.separator ""
    opts.separator "Example: ruby dlgcmd_tool.rb -d dlgcmd.bin -i dlgidx.bin -s output_directory"
    opts.separator ""
    opts.separator "Options:"

    opts.on("-b", "--binary", "Split into/Merge binary files instead of json-files") do
      binary = true
    end

    opts.on("-d", "--dlgcmd [PATH]", "Input/Output-path of dlgcmd-file") do |path|
      dlgcmd_path = path if (path != "" && !path.nil?)
    end

    opts.on("-i", "--dlgidx [PATH]", "Input/Output-path of dlgidx-file") do |path|
      dlgidx_path = path if (path != "" && !path.nil?)
    end

    opts.on("-s", "--split [OUTPUT]",
            "Split given dlgcmd-file. The files are saved to OUTPUT.") do |output|
        folder = output
        split  = true
    end

    opts.on("-m", "--merge [INPUT]",
            "Merges all the files in INPUT and outputs a dlgcmd- and dlgidx-file") do |input|
        folder = input
        split  = false
    end

    opts.on_tail("-h", "--help", "Shows this message") do
      puts opts
      exit
    end
  end

  option_parser.parse!(ARGV)

  if (split)
    split_dlgcmd(dlgcmd_path, dlgidx_path, folder, binary)
  else
    merge_dlgcmd(dlgcmd_path, dlgidx_path, folder, binary)
  end
end
