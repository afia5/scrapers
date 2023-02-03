
module AliScraper
  require 'httparty'
  # require 'hashie'

  #TODO: The method that calls this needs to insert a product and set it to whatever will keep it hidden since it's an aliexpress import
  #and then here we will use that product_id to insert the product details, desc, images and variants
  def self.fetch(ali_id, product_id)
    scrape_url = "https://www.aliexpress.com/item/" + ali_id + ".html" 
    puts "================================================================================="
    puts scrape_url
    puts "================================================================================="
    query             = { api_key: Rails.application.credentials.SCRAPER_API_KEY, country_code: 'us', url: scrape_url }
    unparsed_response = HTTParty.get("https://api.scraperapi.com", query: query, verify: false)
    data              = self.handle_aliexpress_response(unparsed_response)
    #We got no data, we don't want to set the last checked at so that it can rerun faster.
    return if data.blank?
  end

  def self.handle_aliexpress_response(unparsed_response)
    response         = unparsed_response.parsed_response 
    page             = Nokogiri::HTML(response)
    images_array     = []
    json             = page.css('script').select {|s| s.to_s.include? 'actionModule'}
    json_hash        = JSON.parse(json.first.to_s.split("data:")[-1].split("csrfToken:").first.strip[0..-2])
    price_list       = json_hash['skuModule']['skuPriceList']
    prices_array     = fetch_price_list(price_list)
    name             = json_hash['titleModule']['subject']
    thumbnail_url    = json_hash['imageModule']['imagePathList'][0]
    images_array     = images_array + json_hash['imageModule']['imagePathList']
    description_url  = json_hash['descriptionModule']['descriptionUrl']
    description, description_image_urls = get_description(description_url)
    images_array     = images_array + description_image_urls
    variants         = json_hash['skuModule']['skuPriceList']
    variants_array   = fetch_variants(variants)
    product_options  = json_hash['skuModule']['productSKUPropertyList']
    product_options_array, images_urls = fetch_product_options(product_options)
    images_array     = images_array + images_urls
    all_images_array = arrange_images(images_array)
  end

  def self.get_options(value)
    values = value.split('#')[1..]
    values.map { |e| e.split("\;")[0]}
  end

  def self.get_description(description_url)
    query                = { api_key: Rails.application.credentials.SCRAPER_API_KEY, country_code: 'us', url: description_url }
    description_response = HTTParty.get("https://api.scraperapi.com", query: query, verify: false)
    description_response = description_response.parsed_response 
    description_page     = Nokogiri::HTML(description_response.body)
    images_url           = description_page.css('.detail-desc-decorate-richtext img').map { |e| e['src']} rescue []
    description          = description_page.css('.detail-desc-decorate-richtext').to_s rescue nil
    [description, images_url]
  end

  def self.arrange_images(images_array)
    images_array = images_array.uniq
    images_array.delete(nil)
    images_updated_array = []
    counter = 0
    images_array.each do |image_url|
      hash = {}
      hash[:position] = counter+=1
      hash[:url]      = image_url
      images_updated_array << hash
    end
    images_updated_array
  end

  def self.fetch_price_list(price_list)
    prices_array = []
    price_list.each do |record|
      hash           = {}
      hash[:skuId]   = record['skuId']
      hash[:skuAttr] = record['skuAttr']
      hash[:skuVal]  = record['skuVal']
      prices_array << hash
    end
    prices_array
  end

  def self.fetch_product_options(product_options)
    product_options_array = []
    images_urls_array = []
    product_options.each do |option|
      hash = {}
      hash[:name]     = option['skuPropertyName']
      hash[:position] = option['order']
      hash[:values]   = option['skuPropertyValues'].map { |e| e['propertyValueDefinitionName']}
      hash[:values].delete(nil)
      hash[:values]     = (hash[:values].empty?) ? option['skuPropertyValues'].map { |e| e['propertyValueDisplayName']} : hash[:values]
      images            = option['skuPropertyValues'].map {|e| e['skuPropertyImagePath'] }
      images            = images + option['skuPropertyValues'].map {|e| e['skuPropertyImageSummPath'] }
      images_urls_array = images_urls_array + images.uniq
      product_options_array << hash
    end
    [product_options_array, images_urls_array]
  end

  def self.fetch_variants(variants)
    variants_array = []
    counter        = 0
    variants.each do |variant|
      hash = {}
      hash[:position]           = counter+=1
      hash[:Inventory_quantity] = variant['skuVal']['availQuantity']
      hash[:product_price]      = variant['skuVal']['skuActivityAmount']['value'] rescue nil
      hash[:product_price]      = (hash[:product_price].nil?) ? variant['skuVal']['skuAmount']['value'] : hash[:product_price] 
      options                   = get_options( variant['skuAttr'])
      hash[:option1]            = options[0]
      hash[:option2]            = options[1]
      hash[:option3]            = options[3]
      variants_array            << hash
    end
    variants_array
  end
  
end

# AliScraper.fetch('1005004128907672', '')
