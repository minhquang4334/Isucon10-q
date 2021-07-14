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

```
