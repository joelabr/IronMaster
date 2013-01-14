require 'json'

require_relative 'Subdialog.rb'

module IronMaster
  class DlgCmdEntry
    attr_reader :header, :subdialogs

    def initialize
      @header = nil
      @subdialogs = {}
    end

    def self.from_file(file)
      self.new.from_file!(file)
    end

    def from_file!(file)
      @header = Header.from_file(file)

      last_end_offset = 0
      @header.subdialogs_end_offsets.each_pair do |label, end_offset|
        entry_length = file.pos + (end_offset - last_end_offset)
        last_end_offset = end_offset

        @subdialogs[label] = Subdialog.from_file(file, entry_length)
      end

      self
    end

    def self.from_json(string)
      self.new.from_json!(string)
    end

    def from_json!(string)
      data = JSON.load(string)

      @header = Header.from_json(data['header'])

      data['subdialogs'].each_pair do |key, value|
        @subdialogs[key] = Subdialog.from_json(value)
      end

      @header.create_subdialogs_end_offsets_table(@subdialogs)

      self
    end

    def to_file(file)
      @header.to_file(file)

      @subdialogs.each_value do |subdialog|
        subdialog.to_file(file)
      end

      file.write("\x02")
    end

    def to_json(state = nil)
      {
        'header' => @header,
        'subdialogs' => @subdialogs
      }.to_json(state)
    end

    def to_s
      "#{@header}"
    end

    class Header
      attr_reader :size, :id, :label, :number_of_subdialogs, :subdialogs_end_offsets

      def initialize
        @size = 0
        @id = 0
        @label = ""
        @number_of_subdialogs = 0
        @subdialogs_end_offsets = {}
      end

      def calculate_header_size
        @size = 7 + @label.length

        @number_of_subdialogs.times do |i|
          @size += (i + 1).to_s(10).length + 5
          @size += (4 - (@size % 4)) if (@size % 4) != 0
        end
      end

      def create_subdialogs_end_offsets_table(subdialogs)
        current_offset = @size

        subdialogs.each_pair do |key, subdialog|
          current_offset = subdialog.end_offset(current_offset)

          subdialogs_end_offsets[key] = current_offset - @size
        end
      end

      def self.from_file(file)
        self.new.from_file!(file)
      end

      def from_file!(file)
        @id = file.read(4).unpack('I')[0]
        @label = file.gets("\0").chomp("\0")
        @number_of_subdialogs = file.read(2).unpack("S>")[0]

        @number_of_subdialogs.times do
          subdialog_label = file.gets("\0").chomp("\0")

          file.pos += 4 - (file.pos % 4) if (file.pos % 4) != 0
          @subdialogs_end_offsets[subdialog_label] = file.read(4).unpack('I')[0]
        end

        @size = file.pos

        self
      end

      def self.from_json(string)
        self.new.from_json!(string)
      end

      def from_json!(data)
        @id = data['id']
        @label = data['label']
        @number_of_subdialogs = data['number_of_subdialogs']

        calculate_header_size

        self
      end

      def to_file(file)
        file.write([@id, @label, @number_of_subdialogs].pack('IZ*S>'))

        @subdialogs_end_offsets.each do |key, offset|
          file.write([key].pack('Z*'))

          file.pos += 4 - (file.pos % 4) if ((file.pos % 4) != 0)

          file.write([offset].pack('I'))
        end
      end

      def to_json(state)
        {
          'id'                     => @id,
          'label'                  => @label,
          'number_of_subdialogs'   => @number_of_subdialogs
          #'subdialogs_end_offsets' => @subdialogs_end_offsets
        }.to_json(state)
      end

      def to_s
        "ID: #{@id.to_s(16)}\n" +
        "Label: #{@label}\n" +
        "Number of subdialogs: #{@number_of_subdialogs}"
      end
    end
  end
end
