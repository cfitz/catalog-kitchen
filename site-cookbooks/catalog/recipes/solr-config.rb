
# site-cookbooks/recipes/solr-config.rb

# This pretty much is very specific to my Rails application. 
# It configures Solr to use a specific core, sets up that core, and installs the schema, 
# solrconfig and whatnot. It also puts a htpasswd file in the solr directory to be used by the web server...

#
# Most of our setup and configuration is done by hipsnips solr recipe. Here we just add an admin password 
# for nginx basic auth of our solr admin and update paths, and rename the default core to what we want.
# The rails app will handle updating the schema.xml and solrconfig.xml. 
#

# This install a .htpasswd file that nginx will use to put some basic auth in front of Solr. Check out the nginx.conf. 
# also make damn sure that's theres one and only one \n at the end of this.  
execute "printf '#{node[:solr][:admin_user]}:#{node[:solr][:admin_password].chomp}\n'  > /usr/share/solr/.htpasswd"

# this is the solr configuration. for this project, I want to have a single core named blacklight-core
# cookbook_file method looks for source files in the site-cookbooks/catalog/files/ folder. 
cookbook_file '/usr/share/solr/solr.xml' do
  source 'solr.xml'
  owner 'jetty'
  group 'jetty'
  mode '0644'
  action :create
end


#
# The following is very specific to the Blacklight application. This downlaods the Solr configuration for the Blacklight project 
# and installs it in the jetty container. 
if node["blacklight_jetty"]["install"] == true
  remote_file node['blacklight_jetty']['download'] do
    source   node['blacklight_jetty']['link']
    mode     0644
    not_if { ::File.exists?(node['blacklight_jetty']['download']) }
  end

  ruby_block 'Extract Blacklight Jetty' do
    block do
      Chef::Log.info "Extracting Blacklight Jetty archive #{node['blacklight_jetty']['download']} into #{node['jetty']['directory']}"
      `unzip #{node['blacklight_jetty']['download']} -d #{node['jetty']['directory']}`
      raise "Failed to extract Jetty package" unless File.exists?(node['blacklight_jetty']['extracted'])
    end

    action :create

    not_if do
      File.exists?(node['blacklight_jetty']['extracted'])
    end
  end

  # we extract the blacklight configurations only if there's not a blacklight-core dir in the solr home and 
  ruby_block 'Copy Blacklight Jetty Core files' do
    block do
      Chef::Log.info "Copying Blacklight Jetty lib files into #{node['solr']['home']}"
      FileUtils.cp_r File.join(node['blacklight_jetty']['blacklight_core'], "" ), node['solr']['home']
      FileUtils.cp_r File.join(node['blacklight_jetty']['lib'], "" ), node['solr']['home']
      raise "Failed to copy Jetty libraries" if Dir[File.join(node['solr']['home'], 'blacklight-core', '*')].empty?
      raise "Failed to copy Jetty libraries" if Dir[File.join(node['solr']['home'], 'lib', '*')].empty?
    end

    action :create

    not_if do
        File.exists?(File.join( node['solr']['home'], "blacklight-core" )) && File.exists?(node['blacklight_jetty']['blacklight_core'])
    end
  end
end

#
# And finally we need to make sure jetty can update the core's directory
directory "#{node['solr']['home']}/blacklight-core" do
  owner 'jetty'
  group 'jetty'
  recursive true
end

directory "#{node['solr']['home']}/blacklight-core/data" do
  owner 'jetty'
  group 'jetty'
  mode 0750
  recursive true
  notifies :restart, "service[jetty]"
end
