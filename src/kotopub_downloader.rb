# frozen_string_literal: true

require 'nokogiri'
require 'fileutils'
require 'open-uri'
require 'addressable/uri'
require_relative 'kotopub_downloader/epub_generator'

Ebook = Struct.new(:id, :name)

# Download content of a ebook
class Downloader
  def initialize(ebook, config)
    @ebook = ebook
    @download_dir = "#{config[:download]}/#{@ebook.name}"
    @url = "#{config[:url]}/#{@ebook.id}/EPUB"

    @download_list = []
    @blacklist_style = config[:blacklist][:style] || []
    @current = 0
  end

  # Begin download process
  def start
    download_meta

    while (url = @download_list.fetch(@current, false))
      download2file url
      @current += 1
    end
  end

  # Convert content to epub format
  def to_epub
    epub = EpubGenerator.new @download_dir, "#{@download_dir}.epub"
    epub.write
  end

  private

  # Download and parse content urls
  def download(url, dl_path)
    puts "Downloading [#{@current + 1}/#{@download_list.size}]: #{url} ..."
    encoded_url = Addressable::URI.encode(url)

    URI.parse(encoded_url).open do |content|
      # Write to file
      File.open(dl_path, 'wb') do |f|
        f.write parse_content(url, content)
      end
    end
  rescue StandardError => e
    puts "Error: #{url}, #{e.message}"
    # cant download book
    exit if url == "#{@url}/EPUB/package.opf"
  end

  def download2file(url)
    return unless url.to_s.start_with? @url # assert same host

    dl_path = download_path url

    create_path dl_path
    download url, dl_path
  end

  # Create full path directory
  def create_path(path)
    directory = File.dirname(path)
    FileUtils.mkdir_p directory unless Dir.exist?(directory)
  end

  # relative
  def download_path(url)
    path = url.to_s[@url.size..].delete_prefix('/')

    "#{@download_dir}/#{path}"
  end

  # Avoid duplicates
  def add_download(url)
    # return if ['.jpg', '.png', '.gif'].any? File.extname(url.to_s) # Test only
    @download_list << url unless @download_list.any? url
  end

  def download_meta
    download2file("#{@url}/mimetype")
    download2file("#{@url}/META-INF/container.xml")
    download2file("#{@url}/EPUB/package.opf")
  end

  def parse_content(url, content)
    case File.extname(url)
    when '.opf' then parse_package(content)
    when '.css' then parse_css(url, content)
    when '.html' then parse_xhtml(url, content)
    when '.xhtml' then parse_xhtml(url, content)
    else content.read
    end
  end

  # Get manifest items
  def parse_package(content)
    xml = Nokogiri::XML content

    xml.xpath('//xmlns:manifest/xmlns:item').each do |link|
      add_download Addressable::URI.join("#{@url}/EPUB/", link['href'])
    end

    xml.to_s
  end

  def parse_css(url, content)
    links = content.readlines.grep(/url\((?!data)/i)

    # clean urls
    links.map do |link|
      add_download Addressable::URI.join(url, link[/url\(([^)]*)/i, 1].tr('"\'', ''))
    end

    content.seek 0
    content.read
  end

  def parse_xhtml(url, content)
    doc = Nokogiri::HTML content

    # Remove all unwanted
    doc.xpath('//script').remove
    @blacklist_style.each do |style|
      doc.xpath("//link[contains(@href,'#{style}')]").remove
    end

    # Get stylesheets
    doc.xpath('//link').each do |link|
      add_download Addressable::URI.join(url, link['href'])
    end

    doc.to_s
  end
end
