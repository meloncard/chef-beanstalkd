#
# Cookbook Name:: beanstalkd
# Recipe:: default
#
# Copyright 2012-2013, Escape Studios
#

user "beanstalkd" do
	action :create
  comment 'Beanstalkd user'
end

remote_file "/tmp/beanstalkd-#{node[:beanstalkd][:version]}.tar.gz" do
  source "https://github.com/kr/beanstalkd/archive/v#{node[:beanstalkd][:version]}.tar.gz"
  notifies :run, "bash[install_beanstalkd]", :immediately
end

bash "install_beanstalkd" do
	not_if "/usr/bin/beanstalkd --version | grep -q '#{node[:beanstalkd][:version]}'"
  user "root"
  cwd "/tmp"
  code <<-EOH
    tar -zxf beanstalkd-#{node[:beanstalkd][:version]}.tar.gz
    (cd beanstalkd-#{node[:beanstalkd][:version]}/ && make install PREFIX=/usr)
  EOH
  action :nothing
end

case node[:platform]
	when "debian", "ubuntu"
		template_path = "/etc/default/beanstalkd" #templates/ubuntu
	else
		template_path = "/etc/sysconfig/beanstalkd" #templates/default
end

service "beanstalkd" do
	start_command "/etc/init.d/beanstalkd start"
	stop_command "/etc/init.d/beanstalkd stop"
	status_command "/etc/init.d/beanstalkd status"
	supports [:start, :stop, :status]
    #starts the service if it's not running and enables it to start at system boot time
	action :nothing
end

template "beanstalkd.init" do
  path "/etc/init.d/beanstalkd"
  source "beanstalkd.init.erb"
  owner "root"
  group "root"
  mode "0755"
  notifies :enable, "service[beanstalkd]"
  notifies :start, "service[beanstalkd]"
end

# Create the binlog directory
if node[:beanstalkd][:opts][:b]
	directory node[:beanstalkd][:opts][:b] do
	  owner node[:beanstalkd][:opts][:u] if node[:beanstalkd][:opts][:u]
	  mode '0755'
	end
end

template "#{template_path}" do
	source "beanstalkd.erb"
	owner "root"
	group "root"
	mode 0640
	variables(
		:opts => node[:beanstalkd][:opts],
		:start_during_boot => node[:beanstalkd][:start_during_boot]
	)
	notifies :restart, resources(:service => "beanstalkd")
end
