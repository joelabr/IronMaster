#!/usr/bin/env ruby

require_relative '../constants.rb'

module IronMaster
  # Class for handling locstr.bin
  class LocStrFile
    attr_reader :number_of_strings, :offset_to_strings, :strings

    # Creates a new, empty LocStrFile-object
    def initialize
      @strings = Array.new
    end

    # Writes all strings to the given path
    #
    # * *Args*    :
    #   - +output_file+ -> the output path
    #
    def dump_strings(output_file)
      if (@number_of_strings > 0)
        File.open(output_file, "w:UTF-8") do |file|
          @strings.each do |str|
            file.puts(str)
          end
        end
      end
    end

    # Reads the given locstr.bin-file. Returns new LocStrFile-object
    #
    # * *Args*    :
    #   - +input_file+ -> the input locstr-file
    #
    # * *Returns* :
    #   - A new LocStrFile-object with the read data
    #
    def self.from_file(input_file)
      locstr = LocStrFile.new
      locstr.from_file!(input_file)

      locstr
    end

    # Reads the given locstr-bin-file.
    #
    # * *Args*    :
    #   - +input_file+ -> the input locstr-file
    #
    def from_file!(input_file)
      File.open(input_file, "rb:UTF-16LE") do |file|
        @number_of_strings = file.read(4).unpack('I').first
        @offset_to_strings = file.read(4).unpack('I').first

        @number_of_strings.times do
          file.seek(4, File::SEEK_CUR)
          offset = file.read(4).unpack('I').first
          old_offset = file.pos

          file.pos = @offset_to_strings + offset
          strings << file.gets(UTF_16_NULL).encode("UTF-8")

          file.pos = old_offset
        end
      end
    end

    # "Parses" given text file. Returns a new LocStrFile-object
    #
    # * *Args*    :
    #   - +input_file+ -> the file to parse
    #
    # * *Returns* :
    #   - a new LocStrFile-object with the parsed data
    #
    def self.parse_file(input_file)
      locstr = LocStrFile.new
      locstr.parse_file!(input_file)

      locstr
    end

    # "Parses" given text file.
    #
    # * *Args*    :
    #   - +input_file+ -> the file to parse
    # 
    def parse_file!(input_file)
      File.open(input_file, "rb:UTF-8").each("\x00\n") do |line|
        strings << line.chop
      end

      @number_of_strings = @strings.size
      @offset_to_strings = 8 + 8 * @number_of_strings
    end

    # Creates a new locstr-file and writes all the strings to it.
    #
    # * *Args*    :
    #   - +output_file+ -> the output file path
    # 
    def to_file(output_file)
      File.open(output_file, "wb") do |file|
        file.write [@number_of_strings].pack("I")
        file.write [@offset_to_strings].pack("I")

        sum_lengths = 0
        @strings.each_with_index do |str, index|
          file.write [index + 1].pack("I")
          file.write [sum_lengths].pack("I")

          sum_lengths += @strings[index].size * 2
        end

        file.write @strings.join.encode("UTF-16LE")
      end
    end

    def to_s
      "Number of strings: #{@number_of_strings.to_s(16)}" +
      "\nOffset to strings: #{@offset_to_strings.to_s(16)}"
    end
  end
end
