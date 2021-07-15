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
  - https://stackoverflow.com/questions/16559044/using-column-names-as-a-parameter-of-point-geometry-in-mysql
```ruby
estate_ids = estates.map { |estate| estate[:id] }.join(',')
if estate_ids.empty?
  nazotte_estates = []
else
  points = estates.map { |estate| "'POINT(%f %f)'" % estate.values_at(:latitude, :longitude) }
  coordinates_to_text = "'POLYGON((%s))'" % coordinates.map { |c| '%f %f' % c.values_at(:latitude, :longitude) }.join(',')
  text = "CONCAT('POINT(', latitude, ' ', longitude, ')')"
  sql = 'SELECT *, ST_Contains(ST_PolygonFromText(%s), ST_GeomFromText(%s)) as is_geom_contain FROM estate WHERE id IN %s LIMIT %i' % [coordinates_to_text, text, "(#{estate_ids})", NAZOTTE_LIMIT]
  
  estates_in_polygon = db.xquery(sql)
  nazotte_estates = estates_in_polygon.select { |e| e[:is_geom_contain] }
end

```
