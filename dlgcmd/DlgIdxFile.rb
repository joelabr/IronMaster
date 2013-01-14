module IronMaster
  class DlgIdxFile
    attr_reader :number_of_entries, :entries

    def initialize
      @number_of_entries = 0
      @entries           = []
    end

    def self.from_dlgcmd(dlgcmd)
      self.new.from_dlgcmd!(dlgcmd)
    end

    def from_dlgcmd!(dlgcmd)
      last_offset = 0

      dlgcmd.entries.each do |entry|
        @entries << DlgIdxEntry.from_dlgcmd_entry(entry, last_offset)
        #puts "#{last_offset.to_s(16)} (#{entry.header.id.to_s(16)})"

        last_entry = @entries.last
        last_offset += last_entry.header_size + last_entry.data_length
      end

      @entries = @entries.sort {|x, y| x.id <=> y.id}

      @number_of_entries = @entries.size

      self
    end

    def self.from_file(file)
      self.new.from_file!(file)
    end

    def from_file!(file)
      @number_of_entries = file.read(2).unpack('S')[0]

      @number_of_entries.times do |i|
        @entries << DlgIdxEntry.from_file(file)
      end

      self
    end

    def to_file(file)
      file.write([@number_of_entries].pack('S'))
      @entries.each { |entry| entry.to_file(file) }
    end

    def to_s
      "Number of entries: #{@number_of_entries.to_s(16)}"
    end
  end

  class DlgIdxEntry
    attr_reader :id, :offset, :header_size,
                :data_offset, :data_length

    def self.from_dlgcmd_entry(entry, offset)
      self.new.from_dlgcmd_entry!(entry, offset)
    end

    def from_dlgcmd_entry!(entry, offset)
      @id          = entry.header.id
      @offset      = offset
      @header_size = entry.header.size
      @data_offset = @offset + @header_size
      @data_length = entry.header.subdialogs_end_offsets.to_a.last[1] + 1

      self
    end

    def self.from_file(file)
      DlgIdxEntry.new.from_file!(file)
    end

    def from_file!(file)
      entry_data = file.read(20).unpack('IIIII')

      @id          = entry_data[0]
      @offset      = entry_data[1]
      @header_size = entry_data[2]
      @data_offset = entry_data[3]
      @data_length = entry_data[4]

      self
    end

    def to_file(file)
      entry_data = [@id, @offset, @header_size, @data_offset, @data_length].pack('IIIII')

      file.write(entry_data)
    end

    def to_s
      "ID: #{@id.to_s(16)}\n" +
      "Offset: #{@offset.to_s(16)}\n" +
      "Header size: #{@header_size.to_s(16)}\n" +
      "Data offset: #{@data_offset.to_s(16)}\n" +
      "Data length: #{@data_length.to_s(16)}"
    end
  end
end
