puts "\n\n"
puts "*** Deploying to \033[1;41mOPT Server\033[0m"
puts "\n\n"

server '195.169.149.30', :app, :web, :primary => true
