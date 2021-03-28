#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'
require 'open-uri'

BOOK = {
  id: 'xyz',
  name: 'Title'
}.freeze
URL = "https://example.com/books/#{BOOK[:id]}/EPUB"

def download2file(target)
  path = "#{__dir__}/#{BOOK[:name]}/#{target}"
  url = "#{URL}/#{target}"

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
  download2file('EPUB/js/global.js')
end

def parse_package
  links = File.readlines("#{__dir__}/#{BOOK[:name]}/EPUB/package.opf").grep(/href="/)
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

def main
  puts 'Downloading metadata ...'
  download_meta
  links = parse_package

  links.each do |link|
    next if link.start_with? '..' # not member of epub

    puts "Downloading #{link} ..."
    download2file("EPUB/#{link}")
  end

  puts 'Done'
end

main
