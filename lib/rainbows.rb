worker_processes 5
listen ENV['PORT']

Rainbows! do
  use :EventMachine
  worker_connections 50
  keepalive_timeout 0
end
