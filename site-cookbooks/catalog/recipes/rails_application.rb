# site-cookbooks/recipes/rails_application.rb
#

# First thing, lets install the ruby we want, which we can define in the attributes.
rvm_default_ruby  node[:rvm][:default_ruby] do
 action :create
end

# There's a lot going on here. This does some prep work for our rails application, setting up some folder structures, 
# configuring the web server, and setting up a runit service for restarting Unicorn.
#
# this is the location Capistrano will deploy to. But we need to add a few things to get Unicorn working right and have a home 
# for our SSL certs. 
node.set[:deploy_to] = "/var/www/#{node[:server_name]}"

# First,we need to make sure the direct exists and has the right permissions
directory "#{node[:deploy_to]}" do
  owner 'rails'
  group 'www-data'
  recursive true
end

# Here is where the  sockets  for nginx + unicorn will go
directory "#{node[:deploy_to]}/tmp/sockets" do
  owner 'rails'
  group 'www-data'
  recursive true
end

# For our SSL certificates....
directory "#{node[:deploy_to]}/certificate" do
  owner node[:user][:name]
  recursive true
end

# now we add the cert. For anything other than production, I make self-signed certs. 
# like the solr.xml file, there are in the catalog/files/default folder. 
cookbook_file "#{node[:deploy_to]}/certificate/#{node[:environment]}.crt" do
  source "#{node[:environment]}.crt"
  action :create_if_missing
end

cookbook_file "#{node[:deploy_to]}/certificate/#{node[:environment]}.key" do
  source "#{node[:environment]}.key"
  action :create_if_missing
end


# And our database.yml for production.
# I like to add this with Chef then have capistrano symlink after deploy. Among other things, this keeps me 
# from making the stupid mistake of checking my production password into github, since my database password will
# not be in my app code at all. 
rails_creds = Chef::EncryptedDataBagItem.load("passwords", 'rails') # our application specific credentials.
db_creds = Chef::EncryptedDataBagItem.load("passwords", 'mysql') # our root credentials.

template '/etc/database.yml' do
  source 'database.yml.erb'
  owner 'rails'
  group 'rails'
  mode '0644'
  variables(
    :user     => rails_creds['user'],
    :password => rails_creds['password'],
    :database => rails_creds['database']
  )
end


# Configure our database. We need to make a database and user for our rails app. 
# this loads a SQL file with our grants into the DB
execute "mysql-install-rails-privileges" do
  command "/usr/bin/mysql -u root -p#{db_creds["root"]} < /etc/mysql/rails-grants.sql"
  action :nothing
end

# and this configures that grant sql file.
template "/etc/mysql/rails-grants.sql" do
  source "grants.sql.erb"
  owner "root"
  group "root"
  mode "0600"
  variables(
    :user     => rails_creds["user_name"],
    :password => rails_creds['password'],
    :database => rails_creds['database']
  )
  notifies :run, "execute[mysql-install-rails-privileges]", :immediately
end

# and this creates the database, but not if the database already exists....
execute "create #{rails_creds['database']} database" do
  command "/usr/bin/mysqladmin -u root -p#{db_creds["root"]} create #{rails_creds['database']}"
  not_if "mysql -u root -p#{db_creds["root"]} --silent --skip-column-names --execute=\"show databases like '#{rails_creds['database']}'\" | grep #{rails_creds['database']}"
end


# NGINX!

# this enables our site, kinda like a2ensite
execute 'enable-site' do
  command "ln -sf /etc/nginx/sites-available/#{node[:server_name]} /etc/nginx/sites-enabled/#{node[:server_name]}"
  notifies :restart, 'service[nginx]'
end

# Our configuration template. Take a look at templates/nginx.conf.erb to see what's going on. 
template "/etc/nginx/sites-available/#{node[:server_name]}" do
  source 'nginx.erb'
  owner 'root'
  group 'root'
  mode 0644
  notifies :run, "execute[enable-site]", :immediately
  variables(
     server_name: node.server_name
   )
end


# this will create a runit service for our unicorn server. this is a local user service, so
# it can be restarted by rails-application user, who is a non-root user.
["sv", "service"].each do |dir|
  directory "/home/rails/#{dir}" do
    owner node[:user][:name]
    group 'rails'
    user 'rails'
    recursive true
  end
end


runit_service "runsvdir-rails" do 
  default_logger true 
end

runit_service 'railsapp' do
  sv_dir "/home/rails/sv"
  service_dir "/home/rails/service"
  owner 'rails'
  group 'rails'
  restart_command '2'
  restart_on_update false
  default_logger true
  options( deploy_to: node[:deploy_to] )
end

# now add the service and we're done. 
service 'nginx'

execute  "apt-get update; apt-get upgrade; apt-get clean"