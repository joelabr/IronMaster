require 'json'
require 'stringio'

require_relative 'DlgCmdEntry.rb'

module IronMaster
  class DlgCmdFile
    attr_reader :entries

    def initialize
      @entries = []
    end

    #def self.from_file(file, dlgidx)
      #self.new.from_file!(file, dlgidx)
    #end

    #def from_file!(file, dlgidx)
      #dlgidx.entries.each_with_index do |entry, index|
        #if (entry.id == 0x4700000)
          #file.pos = entry.offset
          #length = entry.header_size + entry.data_length

          #StringIO.open(file.read(length), 'rb:ASCII-8BIT') do |string_file|
            #@entries << DlgCmdEntry.from_file(string_file)
          #end
        #end
      #end

      #self
    #end

    def sort(&block)
      @entries = @entries.sort &block
    end

    def sort_by(&block)
      @entries = @entries.sort_by &block
    end
    
    def to_file(file)
      @entries.each do |entry| 
        data = ""
        StringIO.open(data, "wb:ASCII-8BIT") { |string| entry.to_file(string) }

        file.write(data)
      end

      self
    end

    def to_json
      {'entries' => @entries }.to_json
    end

    def to_s
      "Number of entries: #{number_of_entries}"
    end
  end
end
