worker_processes 5
listen ENV['PORT']

Rainbows! do
  use :EventMachine
  worker_connections 50
  keepalive_requests 1000
  keepalive_timeout  10
end
