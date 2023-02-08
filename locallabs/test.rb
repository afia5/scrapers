require 'nokogiri'
require 'open-uri'
require 'json'

document = Nokogiri::HTML.parse(URI.open("https://www.nasa.gov/api/2/ubernode/479003"))
data =  JSON.parse(document)
result = {}
result[:tltle] = data['_source']['title']
result[:date] = data['_source']['promo-date-time'].split("T").first
result[:release_no] = data['_source']['release-id']
result[:article] = data['_source']['body']
puts result
