require 'sinatra'
require 'mongo'
require 'csv'
require 'logger'
require 'redis'
require 'json/streamer'

logger = Logger.new(STDOUT)

class App < Sinatra::Base
  LIMIT = 20
  NAZOTTE_LIMIT = 50
  redis = Redis.new host:"127.0.0.1", port: "6379"

  chair_cond = redis.get(:chair_search_condition);
  if !chair_cond
    chair_cond = File.read('../fixture/chair_condition.json')
    redis.set(:chair_search_condition, chair_cond)
  end
  chair_search_condition = JSON.parse(chair_cond, symbolize_names: true)

  estate_cond = redis.get(:estate_search_condition)
  if !estate_cond
    estate_cond = File.read('../fixture/estate_condition.json')
    redis.set(:estate_search_condition, estate_cond)
  end
  estate_search_condition = JSON.parse(estate_cond, symbolize_names: true)
  configure :development do
    require 'sinatra/reloader'
    register Sinatra::Reloader
  end

  configure do
    enable :logging
  end

  set :add_charset, ['application/json']
  
  client = Mongo::Client.new([ '172.31.40.59:27017' ],
    user: 'isucon',
    password: 'isucon',
    database: 'isuumo',
    write_concern: {w: :majority, wtimeout: 1000}
  )
  client[:estate].indexes.create_one({ 'coor' => '2dsphere' })
  session = client.start_session

  helpers do
    def camelize_keys_for_estate(estate_hash)
      estate_hash.tap do |e|
        e[:doorHeight] = e.delete(:door_height)
        e[:doorWidth] = e.delete(:door_width)
      end
    end

    def body_json_params
      @body_json_params ||= JSON.parse(request.body.tap(&:rewind).read, symbolize_names: true)
    rescue JSON::ParserError => e
      logger.error "Failed to parse body: #{e.inspect}"
      halt 400
    end
  end

  post '/initialize' do
    system("mongoimport --host 172.31.40.59 -u isucon -p isucon --db isuumo --collection chair --drop --jsonArray --file ../mongo/chair.json")
    system("mongoimport --host 172.31.40.59 -u isucon -p isucon --db isuumo --collection estate --drop --jsonArray --file ../mongo/estate.json")
    client[:estate].indexes.create_one({ 'coor' => '2dsphere' })
     
    { language: 'ruby' }.to_json
  end

  post '/deploy' do
    deploy_script = '../../deploy.sh'
    output = %x( #{deploy_script} )
    logger.info("output")

    output.to_json
  end

  get '/api/chair/low_priced' do
    chairs = client[:chair].find({:stock => {'$gt' => 0}}).sort({:price => 1, :id => 1}).limit(LIMIT)
    { chairs: chairs.to_a }.to_json
  end

  get '/api/chair/search' do
    search_queries = []

    if params[:priceRangeId] && params[:priceRangeId].size > 0
      chair_price = chair_search_condition[:price][:ranges][params[:priceRangeId].to_i]
      unless chair_price
        logger.error "priceRangeID invalid: #{params[:priceRangeId]}"
        halt 400
      end

      price = {:price => {}}
      if chair_price[:min] != -1
        price[:price][:$gte] = chair_price[:min]
      end

      if chair_price[:max] != -1
        price[:price][:$lt] = chair_price[:max]
      end

      if !price[:price].empty?
        search_queries << price
      end
    end

    if params[:heightRangeId] && params[:heightRangeId].size > 0
      chair_height = chair_search_condition[:height][:ranges][params[:heightRangeId].to_i]
      unless chair_height
        logger.error "heightRangeId invalid: #{params[:heightRangeId]}"
        halt 400
      end

      height = {:height => {}}
      if chair_height[:min] != -1
        height[:height][:$gte] = chair_height[:min]
      end

      if chair_height[:max] != -1
        height[:height][:$lt] = chair_height[:max]
      end

      if !height[:height].empty?
        search_queries << height
      end
    end

    if params[:widthRangeId] && params[:widthRangeId].size > 0
      chair_width = chair_search_condition[:width][:ranges][params[:widthRangeId].to_i]
      unless chair_width
        logger.error "widthRangeId invalid: #{params[:widthRangeId]}"
        halt 400
      end

      width = {:width => {}}
      if chair_width[:min] != -1
        width[:width][:$gte] = chair_width[:min]
      end

      if chair_width[:max] != -1
        width[:width][:$lt] = chair_width[:max]
      end

      if !width[:width].empty?
        search_queries << width
      end
    end

    if params[:depthRangeId] && params[:depthRangeId].size > 0
      chair_depth = chair_search_condition[:depth][:ranges][params[:depthRangeId].to_i]
      unless chair_depth
        logger.error "depthRangeId invalid: #{params[:depthRangeId]}"
        halt 400
      end

      depth = {:depth => {}}
      if chair_depth[:min] != -1
        depth[:depth][:$gte] = chair_depth[:min]
      end

      if chair_depth[:max] != -1
        depth[:depth][:$lt] = chair_depth[:max]
      end

      if !depth[:depth].empty?
        search_queries << depth
      end
    end

    if params[:kind] && params[:kind].size > 0
      search_queries <<  {:kind => params[:kind]}
    end

    if params[:color] && params[:color].size > 0
      search_queries <<  {:color => params[:color]}
    end

    if params[:features] && params[:features].size > 0
      feature = {:feature => {}}
      
      params[:features].split(',').each do |feature_condition|
        search_queries << {:features => /#{feature_condition}/}
      end
    end

    if search_queries.size == 0
      logger.error "Search condition not found"
      halt 400
    end

    search_queries.push({:stock => {:$gt => 0}})

    page =
      begin
        Integer(params[:page], 10)
      rescue ArgumentError => e
        logger.error "Invalid format page parameter: #{e.inspect}"
        halt 400
      end

    per_page =
      begin
        Integer(params[:perPage], 10)
      rescue ArgumentError => e
        logger.error "Invalid format perPage parameter: #{e.inspect}"
        halt 400
      end
    chairs = client[:chair].find({:$and => search_queries}).limit(per_page).skip(per_page * page)
    { count: chairs.count(), chairs: chairs.to_a }.to_json
  end

  get '/api/chair/:id' do
    id =
      begin
        Integer(params[:id], 10)
      rescue ArgumentError => e
        logger.error "Request parameter \"id\" parse error: #{e.inspect}"
        halt 400
      end

    chair = client[:chair].find({:id => id}).first
    unless chair
      logger.info "Requested id's chair not found: #{id}"
      halt 404
    end

    if chair[:stock] <= 0
      logger.info "Requested id's chair is sold out: #{id}"
      halt 404
    end

    chair.to_json
  end

  post '/api/chair' do
    if !params[:chairs] || !params[:chairs].respond_to?(:key) || !params[:chairs].key?(:tempfile)
      logger.error 'Failed to get form file'
      halt 400
    end

    session.with_transaction(write_concern: {w: :majority}, read: {mode: :primary}) do
      CSV.parse(params[:chairs][:tempfile].read, skip_blanks: true, encoding: 'windows-1251:utf-8') do |row|
        object = {
          :id => row[0].to_s,
          :name => row[1].to_s,
          :description => row[2].to_s,
          :thumbnail => row[3].to_s,
          :price => row[4].to_s,
          :height => row[5].to_s,
          :width => row[6].to_s,
          :depth => row[7].to_s,
          :color => row[8].to_s,
          :features => row[9].to_s,
          :kind => row[10].to_s,
          :popularity => row[11].to_s,
          :stock => row[12].to_s
        }
        client[:chair].insert_one(object)
      end
    end

    status 201
  end

  post '/api/chair/buy/:id' do
    unless body_json_params[:email]
      logger.error 'post buy chair failed: email not found in request body'
      halt 400
    end

    id =
      begin
        Integer(params[:id], 10)
      rescue ArgumentError => e
        logger.error "post buy chair failed: #{e.inspect}"
        halt 400
      end

    session.with_transaction(write_concern: {w: :majority}, read: {mode: :primary}) do
      client[:chair].update_one(
        {
          :$and => [{:id => id}, {:stock => {:$gt => 0}}]
        },
        {
          :$inc => {:stock => -1}
        }
      )
    end

    status 200
  end

  get '/api/chair/search/condition' do
    chair_search_condition.to_json
  end

  get '/api/estate/low_priced' do
     estates = client[:estate].find().sort({:rent => 1, :id => 1}).limit(LIMIT)

     { estates: estates.to_a.map { |e| camelize_keys_for_estate(e) } }.to_json
  end

  get '/api/estate/search' do
    search_queries = []
    query_params = []

    if params[:doorHeightRangeId] && params[:doorHeightRangeId].size > 0
      door_height = estate_search_condition[:doorHeight][:ranges][params[:doorHeightRangeId].to_i]
      unless door_height
        logger.error "doorHeightRangeId invalid: #{params[:doorHeightRangeId]}"
        halt 400
      end

      door_height = {:door_height => {}}
      if door_height[:min] != -1
        door_height[:door_height][:$gte] = door_height[:min]
      end

      if door_height[:max] != -1
        door_height[:door_height][:$lt] = door_height[:max]
      end

      if !door_height[:door_height].empty?
        search_queries << door_height
      end
    end

    if params[:doorWidthRangeId] && params[:doorWidthRangeId].size > 0
      door_width = estate_search_condition[:doorWidth][:ranges][params[:doorWidthRangeId].to_i]
      unless door_width
        logger.error "doorWidthRangeId invalid: #{params[:doorWidthRangeId]}"
        halt 400
      end

      door_width = {:door_width => {}}
      if door_width[:min] != -1
        door_width[:door_width][:$gte] = door_width[:min]
      end

      if door_width[:max] != -1
        door_width[:door_width][:$lt] = door_width[:max]
      end

      if !door_width[:door_width].empty?
        search_queries << door_width
      end
    end

    if params[:rentRangeId] && params[:rentRangeId].size > 0
      rent = estate_search_condition[:rent][:ranges][params[:rentRangeId].to_i]
      unless rent
        logger.error "rentRangeId invalid: #{params[:rentRangeId]}"
        halt 400
      end

      rent = {:rent => {}}
      if rent[:min] != -1
        rent[:rent][:$gte] = rent[:min]
      end

      if rent[:max] != -1
        rent[:rent][:$lt] = rent[:max]
      end

      if !rent[:rent].empty?
        search_queries << rent
      end
    end

    if params[:features] && params[:features].size > 0
      feature = {:feature => {}}
      
      params[:features].split(',').each do |feature_condition|
        search_queries << {:features => /#{feature_condition}/}
      end
    end

    if search_queries.size == 0
      logger.error "Search condition not found"
      halt 400
    end

    page =
      begin
        Integer(params[:page], 10)
      rescue ArgumentError => e
        logger.error "Invalid format page parameter: #{e.inspect}"
        halt 400
      end

    per_page =
      begin
        Integer(params[:perPage], 10)
      rescue ArgumentError => e
        logger.error "Invalid format perPage parameter: #{e.inspect}"
        halt 400
      end

    estates = client[:estate].find({:$and => search_queries}).limit(per_page).skip(per_page * page)
    { count: estates.count(), estates: estates.to_a }.to_json
  end

  post '/api/estate/nazotte' do
    coordinates = body_json_params[:coordinates]

    unless coordinates
      logger.error "post search estate nazotte failed: coordinates not found"
      halt 400
    end

    if !coordinates.is_a?(Array) || coordinates.empty?
      logger.error "post search estate nazotte failed: coordinates are empty"
      halt 400
    end

    cor_array = coordinates.map{ |c| c.values_at(:longitude, :latitude) }
    estates_in_polygon = client[:estate].find({
      :coor => {
        :$geoWithin => {
          :$geometry => {
            :type => "Polygon",
            :coordinates => [cor_array]
          }
        }
      }
    }).limit(NAZOTTE_LIMIT)

    nazotte_estates = estates_in_polygon.to_a
    {
      estates: nazotte_estates.map { |e| camelize_keys_for_estate(e) },
      count: nazotte_estates.size,
    }.to_json
  end

  get '/api/estate/:id' do
    id =
      begin
        Integer(params[:id], 10)
      rescue ArgumentError => e
        logger.error "Request parameter \"id\" parse error: #{e.inspect}"
        halt 400
      end

    estate = client[:estate].find({:id => id}).first
    unless estate
      logger.info "Requested id's estate not found: #{id}"
      halt 404
    end

    camelize_keys_for_estate(estate).to_json
  end

  post '/api/estate' do
    unless params[:estates]
      logger.error 'Failed to get form file'
      halt 400
    end

    session.with_transaction(write_concern: {w: :majority}, read: {mode: :primary}) do
      CSV.parse(params[:estates][:tempfile].read, skip_blanks: true, encoding: 'windows-1251:utf-8') do |row|
        object = {
          :id => row[0].to_s,
          :name => row[1].to_s,
          :description => row[2].to_s,
          :thumbnail => row[3].to_s,
          :address => row[4].to_s,
          :latitude => row[5].to_s,
          :longitude => row[6].to_s,
          :rent => row[7].to_s,
          :door_height => row[8].to_s,
          :door_width => row[9].to_s,
          :features => row[10].to_s,
          :popularity => row[11].to_s
        }
        client[:estate].insert_one(object)
      end
    end

    status 201
  end

  post '/api/estate/req_doc/:id' do
    unless body_json_params[:email]
      logger.error 'post request document failed: email not found in request body'
      halt 400
    end

    id =
      begin
        Integer(params[:id], 10)
      rescue ArgumentError => e
        logger.error "post request document failed: #{e.inspect}"
        halt 400
      end

    estate = client[:estate].find({:id => id}).first
    unless estate
      logger.error "Requested id's estate not found: #{id}"
      halt 404
    end

    status 200
  end

  get '/api/estate/search/condition' do
    estate_search_condition.to_json
  end

  get '/api/recommended_estate/:id' do
    id =
      begin
        Integer(params[:id], 10)
      rescue ArgumentError => e
        logger.error "Request parameter \"id\" parse error: #{e.inspect}"
        halt 400
      end

    chair = client[:estate].find({:id => id}).first
    unless chair
      logger.error "Requested id's chair not found: #{id}"
      halt 404
    end

    w = chair[:width]
    h = chair[:height]
    d = chair[:depth]

    query = {
      :$or => [
        {
          :$and => [
            { :door_width => { :$gte => w } },
            { :door_height => { :$gte => h } }
          ]
        },
        {
          :$and => [
            { :door_width => { :$gte => w } },
            { :door_height => { :$gte => d } }
          ]
        },
        {
          :$and => [
            { :door_width => { :$gte => h } },
            { :door_height => { :$gte => w } }
          ]
        },
        {
          :$and => [
            { :door_width => { :$gte => h } },
            { :door_height => { :$gte => d } }
          ]
        },
        {
          :$and => [
            { :door_width => { :$gte => d } },
            { :door_height => { :$gte => w } }
          ]
        },
        {
          :$and => [
            { :door_width => { :$gte => d } },
            { :door_height => { :$gte => h } }
          ]
        },
      ]
    }
    estates = client[:estate].find(query).sort({:popularity => -1, :id => 1}).limit(LIMIT)
    { estates: estates.to_a.map { |e| camelize_keys_for_estate(e) } }.to_json
  end
end
