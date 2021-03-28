#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../src/kotopub_downloader'

CONFIG[:ebooks].each do |eb|
  ebook = Ebook.new(eb[:id], eb[:name])

  downloader = Downloader.new ebook
  downloader.start
end
