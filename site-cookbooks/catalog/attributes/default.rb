# site-cookbooks/catalog/attributes/default.rb. 

#
# This is a big long boring list of attributes that the recipes will use. 
# To find all the options that are available to you, you'll have to look at the recipe's documentation. 
# If you're following along at home, make this file and paste in the values you see from Github. 
# We'll be coming back to these as we run through our recipes.
#


# sets the ruby version to be installed by RVM. note that I'm making a gemset for the rails application. 
default.rvm.default_ruby = "ruby-1.9.3-p392@blacklight_app"

# some default packages we want to install
default.packages = %w(vim git tmux openssl xinetd nullmailer unzip)

# Users
default.users = ['chrisfitzpatrick', 'rails']
default.user.ssh_keygen = false

# SSH 
default.openssh.server.permit_root_login = 'no'
default.openssh.server.password_authentication = 'no'
default.openssh.server.allow_groups = 'sudo'
default.openssh.server.login_grace_time = '30'
default.openssh.server.use_p_a_m = 'no'
default.openssh.server.print_motd = 'no'


# Solr
default.solr.version = '4.2.1'
default.solr.checksum = '648a4b2509f6bcac83554ca5958cf607474e81f34e6ed3a0bc932ea7fac40b99'
default.solr.admin_user = "solr"
# like this: openssl passwd -1 V3RySEcRe7 this example uses MD5 encryption
default.solr.admin_password =  "$1$E9gEtN.b$soUxfCdSW9OowbZ/SAAlq1" 

default.nginx.init_style = "runit"
default.nginx.default_site_enabled = false

# our Jetty variables
default.jetty.port = 8983
default.jetty.version = '9.0.3.v20130506'
default.jetty.link = 'http://eclipse.org/downloads/download.php?file=/jetty/stable-9/dist/jetty-distribution-9.0.3.v20130506.tar.gz&r=1'
default.jetty.checksum = '79a6951ff3a773f9678bfe3750e8f1545d68c92a'
default.jetty.java_options = []
default.java.jdk_version = "7"

# newrelic
newrelic_creds = Chef::EncryptedDataBagItem.load("passwords", 'newrelic')
default.new_relic.repository_key = newrelic_creds["repository_key"]
default.new_relic.license_key = newrelic_creds["license_key"]


# Defines our Mailer and Apticron
default.smtp.mailhost = 'gmail'
default.apticron.email = 'somedinkyassemail@gmail.com'
default.apticron.diff_only = false
default.apticron.notify_no_updates = false


# This is all stuff specific to the Blacklight code. This points to the Solr configurations that need to be installed.
default.blacklight_jetty.install = true
default.blacklight_jetty.link = "https://github.com/projectblacklight/blacklight-jetty/archive/v4.0.0.zip"
default.blacklight_jetty.download = "#{node['jetty']['directory']}/v4.0.0.zip"
default.blacklight_jetty.extracted = "#{node['jetty']['directory']}/blacklight-jetty-4.0.0"
default.blacklight_jetty.blacklight_core = "#{node['jetty']['directory']}/blacklight-jetty-4.0.0/solr/blacklight-core"
default.blacklight_jetty.lib = "#{node['jetty']['directory']}/blacklight-jetty-4.0.0/solr/lib"
