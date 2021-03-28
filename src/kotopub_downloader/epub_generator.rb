# frozen_string_literal: true

require 'zip'

# Create a epub+zip file from folder
# Based on https://github.com/rubyzip/rubyzip/blob/v2.3.0/test/entry_test.rb#L124
class EpubGenerator
  # Initialize with the directory to zip and the location of the output archive
  def initialize(input_dir, output_file)
    @input_dir = input_dir
    @output_file = output_file
  end

  # Zip the input directory
  def write
    File.delete(@output_file) if File.exist?(@output_file)

    Zip::File.open(@output_file, Zip::File::CREATE) do |zipfile|
      zipfile.add(mimetype_entry(zipfile), "#{@input_dir}/mimetype")

      all_entries.each do |file|
        zipfile.add(file, "#{@input_dir}/#{file}")
      end
    end
  end

  private

  # A helper method to make the recursion work.
  def all_entries
    entries = []
    Dir.chdir(@input_dir) do
      entries = Dir.glob(File.join('**', '**')) - %w[mimetype]
    end

    entries
  end

  def mimetype_entry(zipfile)
    mimetype = Zip::Entry.new(zipfile, 'mimetype')
    mimetype.compression_method = Zip::Entry::STORED

    mimetype
  end
end
