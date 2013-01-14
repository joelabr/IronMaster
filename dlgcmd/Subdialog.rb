require 'json'

require_relative '../constants.rb'

module IronMaster
  class Subdialog
    attr_reader :entries

    def initialize
      @entries = []
    end

    def end_offset(offset)
      @entries.each do |entry|
        offset += entry.calculate_size(offset)
      end

      offset
    end

    def self.from_file(file, length)
      self.new.from_file!(file, length)
    end

    def from_file!(file, length)
      while (file.pos < length && !file.eof?)
        type = file.getbyte

        @entries << case type
          when 0x02 then
            file.pos += 1
            EndEntry.new
          when 0x03 then TextEntry.from_file(file)
          when 0x04 then ConditionEntry.from_file(file)
          when 0x05 then UnknownEntry.from_file(file)
          when 0x06 then JumpEntry.from_file(file)
          else
            puts "Invalid type #{sprintf("0x%02X", type)}"
            file.pos += 1
            Entry.new()
        end
      end

      self
    end

    def self.from_json(data)
      self.new.from_json!(data)
    end

    def from_json!(data)
      @entries = data['entries'].map do |entry|
        case entry['type']
          when 0x02 then EndEntry.new
          when 0x03 then TextEntry.from_json(entry)
          when 0x04 then ConditionEntry.from_json(entry)
          when 0x05 then UnknownEntry.from_json(entry)
          when 0x06 then JumpEntry.from_json(entry)
          else Entry.new
        end
      end

      self
    end

    def to_file(file)
      @entries.each { |entry| entry.to_file(file) }
    end

    def to_json(state)
      { 'entries' => @entries }.to_json(state)
    end

    def to_s
      "Number of entries: #{@entries.size}"
    end

    class Entry
      attr_reader :type

      def initialize
        @type = 0
      end

      def calculate_size(offset)
        1
      end

      def self.from_file(file)
        self.new.from_file!(file)
      end

      def from_file!(file)
        self
      end

      def self.from_json(data)
        self.new.from_json!(data)
      end

      def from_json!(data)
        self
      end

      def to_file(file)
        file.write([@type].pack('C'))
      end

      def to_json(state)
        hash = {}
        self.instance_variables.each do |variable|
          hash[variable[1..-1]] = self.instance_variable_get(variable)
        end

        hash.to_json(state)
      end

      def to_s
        "Type: #{@type}"
      end
    end

    class ConditionEntry < Entry
      attr_reader :id, :number_of_options, :options
      def initialize
        @type              = 4
        @id                = ""
        @number_of_options = 0
        @options           = {}
      end

      def calculate_size(offset)
        start_offset = offset
        
        offset += 3 + @id.length

        @options.each do |index, label|
          offset += 4 - (offset % 4) if (offset % 4) != 0
          offset += 5 + label.length
        end

        offset - start_offset
      end

      def from_file!(file)
        @id                = file.gets("\0").chomp("\0")
        @number_of_options = file.getbyte

        @number_of_options.times do
          file.pos += 4 - (file.pos % 4) if (file.pos % 4) != 0

          index = file.read(4).unpack('I')[0]
          label = file.gets("\0").chomp("\0")

          @options[index] = label
        end

        self
      end

      def from_json!(data)
        @id                = data['id']
        @number_of_options = data['number_of_options']
        @options           = Hash[data['options'].map { |entry| [entry[0].to_i, entry[1]] }]

        self
      end

      def to_file(file)
        super

        file.write([@id, @number_of_options].pack("Z*C"))
        
        @options.each do |index, label|
          file.pos += 4 - (file.pos % 4) if (file.pos % 4) != 0

          file.write([index, label].pack("IZ*"))
        end
      end

      def to_s
        "#{super}\n" +
        "ID: #{@id}\n" +
        "Number of options: #{@number_of_options}"
      end
    end

    class EndEntry < Entry
      def initialize
        type = 0x02
      end
    end

    class JumpEntry < Entry
      attr_reader :label

      def initialize
        @type  = 0x06
        @label = "\0"
      end

      def calculate_size(offset)
        2 + @label.length
      end

      def from_file!(file)
        @label = file.gets("\0").chomp("\0")

        self       
      end

      def from_json!(data)
        @label = data['label']

        self
      end

      def to_file(file)
        super

        file.write([@label].pack("Z*"))
      end

      def to_s
        "#{super}\n" +
        "Label: #{@label}"
      end
    end

    class TextEntry < Entry
      attr_reader :id, :text, :mirror_image, :has_icon, :icon_id,
                  :number_of_options, :option_labels

      def initialize
        @type              = 3
        @id                = ""
        @text              = ""
        @mirror_image      = 0
        @display_icon      = 0
        @icon_id           = ""
        @number_of_options = 0
        @option_labels     = []
      end

      def calculate_size(offset)
        start_offset = offset

        offset += 2 + @id.length
        offset += 1 if (offset % 2) != 0
        offset += 5 + (2 * @text.length)

        offset += 1 + @icon_id.length if (@display_icon == 1)

        if (@number_of_options > 0)
          offset += 1 if (offset % 2) != 0 

          @option_labels.each do |label|
            offset += 2 + (2 * label.length)
            offset += 1 if (offset % 2) != 0
          end
        end

        offset - start_offset
      end

      def from_file!(file)
        @id = file.gets("\0").chomp("\0")

        file.pos += 1 if (file.pos % 2) != 0

        encoding = file.external_encoding
        file.set_encoding("UTF-16LE")
        @text = file.readline(UTF_16_NULL).encode("UTF-8").chomp("\0")
        file.set_encoding(encoding)

        @mirror_image, @display_icon = file.read(2).unpack("CC")

        @icon_id = file.gets("\0").chomp("\0") if (@display_icon == 1)

        @number_of_options = file.getbyte

        if (@number_of_options > 0)
          file.pos += 1 if (file.pos % 2) != 0

          encoding = file.external_encoding
          file.set_encoding("UTF-16LE")
          @number_of_options.times do
            @option_labels << file.gets(UTF_16_NULL).encode("UTF-8").chomp("\0")
            file.pos += 1 if (file.pos % 2) != 0
          end
          file.set_encoding(encoding)
        end

        self
      end

      def from_json!(data)
        @id                = data['id']
        @text              = data['text']
        @mirror_image      = data['mirror_image']
        @display_icon      = data['display_icon']
        @icon_id           = data['icon_id']
        @number_of_options = data['number_of_options']
        @option_labels     = data['option_labels']

        self
      end

      def to_file(file)
        super

        file.write([@id].pack("Z*"))

        file.pos += 1 if (file.pos % 2) != 0

        encoding = file.external_encoding
        file.set_encoding("UTF-16LE")
        file.write(@text.encode("UTF-16LE") + UTF_16_NULL)
        file.set_encoding(encoding)

        file.write([@mirror_image, @display_icon].pack('CC'))

        file.write([@icon_id].pack("Z*")) if (@display_icon == 1)

        file.write([@number_of_options].pack('C'))

        if (@number_of_options > 0)
          file.pos += 1 if (file.pos % 2) != 0

          encoding = file.external_encoding
          file.set_encoding("UTF-16LE")
          @option_labels.each do |label|
            file.write(label.encode("UTF-16LE") + UTF_16_NULL)
            file.pos += 1 if (file.pos % 2) != 0
          end
          file.set_encoding(encoding)
        end
      end

      def to_s
        "#{super}\n" +
        "ID: #{@id}\n" +
        "Text: #{@text}\n" +
        "Mirror image: #{@mirror_image}\n" +
        "Display icon: #{@display_icon}\n" +
        "Icon ID: #{@icon_id}\n" +
        "Number of option labels: #{@number_of_options}"
      end
    end

    class UnknownEntry < Entry
      attr_reader :unknown, :unknown2, :dlgcmd_entry_id, :unknown3

      def initialize
        @type            = 5
        @unknown         = 1
        @unknown2        = 0 
        @dlgcmd_entry_id = 0
        @unknown3        = 0
      end

      def calculate_size(offset)
        start_offset = offset

        offset += 2
        offset += 4 - (offset % 4) if (offset % 4) != 0
        offset += 8

        offset - start_offset
      end

      def from_file!(file)
        @unknown = file.read(1).unpack('C')[0]

        file.pos += 4 - (file.pos % 4) if (file.pos % 4) != 0
        @unknown2, @dlgcmd_entry_id, @unknown3 = file.read(8).unpack("SIS")

        self
      end

      def from_json!(data)
        @unknown         = data['unknown']
        @unknown2        = data['unknown2']
        @dlgcmd_entry_id = data['dlgcmd_entry_id']
        @unknown3        = data['unknown3']

        self
      end

      def to_file(file)
        super

        file.write([@unknown].pack('C'))

        file.pos += 4 - (file.pos % 4) if (file.pos % 4) != 0
        file.write([@unknown2, @dlgcmd_entry_id, @unknown3].pack("SIS"))
      end

      def to_s
        "#{super}\n" +
        "Unknown: #{@unknown}\n" +
        "Unknown2: #{@unknown2}\n" +
        "DlgCmdEntry ID: #{@dlgcmd_entry_id}\n" +
        "Unknown3: #{@unknown3}"
      end
    end
  end
end
