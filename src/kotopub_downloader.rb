# frozen_string_literal: true

require 'yaml'
require 'fileutils'
require 'open-uri'
require_relative 'kotopub_downloader/epub_generator'

CONFIG = YAML.load_file('config.yml')
Ebook = Struct.new(:id, :name)

# Download content of a ebook
class Downloader
  def initialize(ebook)
    @ebook = ebook
    @download_dir = "#{CONFIG[:download]}/#{@ebook.name}"
    @url = "#{CONFIG[:url]}/#{@ebook.id}/EPUB"
  end

  def start
    puts "Downloading #{@ebook.name} metadata ..."
    download_meta
    links = parse_package

    links.each do |link|
      next if link.start_with? '..' # not member of epub

      puts "Downloading #{link} ..."
      download2file("EPUB/#{link}")
    end

    puts "Done #{@ebook.name}"
  end

  def to_epub
    epub = EpubGenerator.new "#{CONFIG[:download]}/#{@ebook.name}", CONFIG[:download]
    epub.write
  end

  private

  def download2file(target)
    path = "#{@download_dir}/#{target}"
    url = "#{@url}/#{target}"

    # create full path directory
    directory = File.dirname(path)
    FileUtils.mkdir_p directory unless Dir.exist?(directory)

    # download
    URI.parse(url).open do |content|
      File.open(path, 'wb') { |f| f.write(content.read) }
    end
  end

  def download_meta
    download2file('mimetype')
    download2file('META-INF/container.xml')
    download2file('EPUB/package.opf')
    # stylesheet
    download2file('EPUB/css/base.css')
    download2file('EPUB/css/global.css')
    # download2file('EPUB/js/global.js') # really need this?
  end

  def parse_package
    links = File.readlines("#{@download_dir}/EPUB/package.opf").grep(/href="/)
    stylesheets = []

    # clean urls
    links.map! do |link|
      link[/href="([^"]*)"/, 1]
    end

    links.each do |link|
      css = link[%r{xhtml/epub[^/]*}]
      stylesheets << "#{css}/OEBPS/css/idGeneratedStyles.css" if css
    end

    links + stylesheets.uniq
  end
end
