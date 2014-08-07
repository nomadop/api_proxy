json.array!(@directions) do |direction|
  json.extract! direction, :id, :origin, :destination, :status, :options
  json.url direction_url(direction, format: :json)
end
