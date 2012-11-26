require_relative 'LocStrFile.rb'

module IronMaster
  # Prints help
  def self.print_help
    puts "Usage:"
    puts "ruby locstr_tool.rb OPTION INPUT OUTPUT"
    puts "\tOPTIONS"
    puts "\t-d : Dump locstr.bin to textfile"
    puts "\t-p : Parse textfile to a locstr-file"
  end

  # Parse the arguments
  if (ARGV.size > 2)
    if (ARGV[0] == "-d")  # Dump locstr.bin to textfile
      puts "Reading locstr-file \"#{ARGV[1]}\""
      locstr = LocStrFile.from_file(ARGV[1])
      
      puts locstr
      
      puts "Dumping strings to \"#{ARGV[2]}\""
      locstr.dump_strings(ARGV[2])
    elsif (ARGV[0] == "-p") # Parse textfile to a locstr-file
      puts "Parsing \"#{ARGV[1]}\""
      locstr = LocStrFile.parse_file(ARGV[1])

      puts locstr

      puts "Writing locstr-file \"#{ARGV[2]}\""
      locstr.to_file(ARGV[2])
    else
      puts "No such option!"
      print_help
      exit
    end
  else
    print_help
  end
end
