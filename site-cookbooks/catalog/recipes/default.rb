# site-cookbooks/catalog/recipes/default.rb

# This recipe is also installing a bunch of services, but these have to be configured 
# a little bit more than just setting attributes allows. 

# For example, to setup the apticron service, I install the package then use a template
# (located in templates/default/articron.conf.erb) that accecpts variables.

# I do this for my mailer as well.

# For iptables, I not only run the recipe but utilize the LWRP that the iptables 
# cookbook provides to configure the firewall.  


# apticron service for package notification
package 'apticron'
template '/etc/apticron/apticron.conf' do
  source 'apticron.conf.erb'
  owner 'root'
  group 'root'
  mode '0644'
  variables(
    email: node.apticron.email,
    diff_only: node.apticron.diff_only,
    notify_no_updates: node.apticron.notify_no_updates
  )
end


# This is a really simple setup for email that uses Gmail SMTP 
mailhost_creds = Chef::EncryptedDataBagItem.load("passwords", node.smtp.mailhost)
unless mailhost_creds.nil?
  template '/usr/bin/gmail-smtp' do
    source 'gmail-smtp.erb'
    owner 'root'
    group 'rails'
    mode '0750'
  end
  
  template '/etc/xinetd.d/gmail-smtp' do
    owner 'root'
    group 'rails'
    mode '0750'
    source 'gmail-smtp.conf.erb'
  end
  
  template '/etc/nullmailer/remotes' do
    source 'remotes.erb'
    owner 'root'
    group 'rails'
    mode '0750'
    variables(
      mailhost_creds: mailhost_creds
    )
  end
    
  execute "restart nullmailer and xinetd" do
    command " /etc/init.d/nullmailer reload; /etc/init.d/xinetd reload"
    action :run
  end

end

# And secure it with iptables. Jetty will be fronted by nginx, so we only need http ports
include_recipe 'simple_iptables'
simple_iptables_policy 'INPUT' do
  policy 'DROP'
end

simple_iptables_rule "http" do
  rule [ "--proto tcp --dport 80",
         "--proto tcp --dport 443" ]
  jump "ACCEPT"
end
# Currently we don't need tp receive mail...
# simple_iptables_rule "mail" do
#   rule [ "-o eth0 -p tcp --sport 587 -m state --state NEW,ESTABLISHED",
#          "-o eth0 -p tcp --dport 587 -m state --state NEW,ESTABLISHED",
#          "-i eth0 -p tcp --sport 587 -m state --state ESTABLISHED"
#           ]
#   jump "ACCEPT"
# end

simple_iptables_rule 'system' do
  rule '-i lo'
  jump 'ACCEPT'
end
simple_iptables_rule 'system' do
  rule '-m conntrack --ctstate ESTABLISHED,RELATED'
  jump 'ACCEPT'
end
simple_iptables_rule 'system' do
  rule '-p icmp'
  jump 'ACCEPT'
end
simple_iptables_rule 'system' do
  rule '-p tcp --dport ssh'
  jump 'ACCEPT'
end


# now we move one to configure our solr and web server
include_recipe "catalog::solr-config"
include_recipe "catalog::rails_application"


