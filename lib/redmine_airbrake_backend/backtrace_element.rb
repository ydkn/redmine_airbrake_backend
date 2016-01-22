require 'digest/md5'


module RedmineAirbrakeBackend
  # Backtrace element received by airbrake
  class BacktraceElement
    attr_reader :file, :line, :function, :column

    def initialize(data)
      # File
      @file = data[:file].presence

      # Line
      @line = data[:line].presence

      # Function
      @function = data[:function].presence

      # Column
      @column = data[:column].presence
    end

    def checksum
      @_checksum ||= Digest::MD5.hexdigest("#{@file}|#{normalize_function_name(@function)}|#{@line}|#{@column}")
    end

    private

    def normalize_function_name(function_name)
      name = @function
        .downcase
        .gsub(/_\d+_/, '') # ruby blocks

      RedmineAirbrakeBackend.filter_hex_values(name)
    end
  end
end
