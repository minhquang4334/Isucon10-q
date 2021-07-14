## POST /api/estate/nazotte
```
  SELECT * FROM estate WHERE latitude <= ? AND latitude >= ? AND longitude <= ? AND longitude >= ? ORDER BY popularity DESC, id ASC
```
- N + 1
```ruby
estates_in_polygon = []
estates.each do |estate|
  point = "'POINT(%f %f)'" % estate.values_at(:latitude, :longitude)
  coordinates_to_text = "'POLYGON((%s))'" % coordinates.map { |c| '%f %f' % c.values_at(:latitude, :longitude) }.join(',')
  sql = 'SELECT * FROM estate WHERE id = ? AND ST_Contains(ST_PolygonFromText(%s), ST_GeomFromText(%s))' % [coordinates_to_text, point]
  e = db.xquery(sql, estate[:id]).first
  if e
    estates_in_polygon << e
  end
end
```
- fix
```ruby
estate_ids = estates.map { |estate| estate[:id] }
points = estates.map { |estate| "'POINT(%f %f)'" % estate.values_at(:latitude, :longitude) }
coordinates_to_text = "'POLYGON((%s))'" % coordinates.map { |c| '%f %f' % c.values_at(:latitude, :longitude) }.join(',')

sql = 'SELECT *, ST_Contains(ST_PolygonFromText(%s), ST_GeomFromText(POINT(latitude longitude))) FROM estate WHERE id IN ? LIMIT ?' % [coordinates_to_text]

estates_in_polygon = db.xquery(sql, estate_ids, NAZOTTE_LIMIT)
nazotte_estates = estates_in_polygon.select { |e| e.is_geom_contain }
```


## POST /api/estate
- Send file to Server and read file
- 列ごとにInsert Queryが発行される
- すごく大きいファイルの場合はInsertのクエリは何回も発行される
```ruby
post '/api/estate' do
  unless params[:estates]
    logger.error 'Failed to get form file'
    halt 400
  end

  transaction('post_api_estate') do
    CSV.parse(params[:estates][:tempfile].read, skip_blanks: true) do |row|
      sql = 'INSERT INTO estate(id, name, description, thumbnail, address, latitude, longitude, rent, door_height, door_width, features, popularity) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
      db.xquery(sql, *row.map(&:to_s))
    end
  end

  status 201
end
```
- fix: Valuesを生成したあと、Insertクエリが発行されるように修正
```ruby
post '/api/estate' do
  unless params[:estates]
    logger.error 'Failed to get form file'
    halt 400
  end

  arr_values = []
  CSV.parse(params[:estates][:tempfile].read, skip_blanks: true) do |row|
    v = "(%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)" % *row.map(&:to_s)
    arr_values << v
  end
  values = arr_values.join(',')

  sql = 'INSERT INTO estate(id, name, description, thumbnail, address, latitude, longitude, rent, door_height, door_width, features, popularity) VALUES ?'
  db.xquery(sql, values)

  status 201
end