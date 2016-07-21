# Author:: Ross Smith (<rjsm@umich.edu>)
# Cookbook Name:: caen-client
# Recipe:: configure
#
# Apache 2.0
#

# get file from bucket
ruby_block "download-object" do
  block do
    require 'aws-sdk'

    s3 = AWS::S3.new

    myfile = s3.buckets['linuxinfrastructure-files'].objects['ansible-files/packages/ansible-2.1.0.0-1.amzn1.noarch.rpm']
    Dir.chdir("/tmp")
    File.open("ansible.rpm", "w") do |f|
      f.syswrite(myfile.read)
      f.close
    end
  end
  action :run
end

# install ansible from our package
package "ansible" do
  case node[:platform]
  when 'amazon'
    source "/tmp/ansible.rpm"
  #when 'centos', 'redhat', 'fedora'
  #  package_name 'ansible'
  end
  action :upgrade
end

#drop config file
template "/etc/cron.d/ansible-pull" do
  source 'pull.erb'
  owner "root"
  group "root"
  mode "0644"
end

#run our pull once, so it's setup for ansible
execute "ansible-pull" do
  command  '/usr/bin/ansible-pull -d /var/ansible/checkout/ -C pull -U https://github.com/CAEN/ansible-configuration  playbooks/local.yml -i hosts '
end
# try to set tags
ruby_block "set-tags" do
  block do
    require 'aws-sdk'

    AWS.config(region: node["opsworks"]["instance"]["region"])

    inst = AWS::EC2::Instance.new(node["opsworks"]["instance"]["aws_instance_id"])
    inst.tag('Shortcode', :value => node["caen"]["Shortcode"])
    inst.tag('Purpose', :value => node["caen"]["Purpose"])
    inst.tag('Role', :value => node["caen"]["Role"])
    inst.tag('Owner', :value => node["caen"]["Owner"])

    inst.network_interfaces().each {
        |iface|
        iface.tag('Shortcode', :value => node["caen"]["Shortcode"])
        iface.tag('Purpose', :value => node["caen"]["Purpose"])
        iface.tag('Role', :value => node["caen"]["Role"])
        iface.tag('Owner', :value => node["caen"]["Owner"])
        iface.tag('Name', :value => node["opsworks"]["instance"]["hostname"])
    }

    inst.block_devices().each {
        |block|
        if block[:ebs] != nil then
            bd = AWS::EC2::Volume.new(block[:ebs][:volume_id])
            bd.tag('Shortcode', :value => node["caen"]["Shortcode"])
            bd.tag('Purpose', :value => node["caen"]["Purpose"])
            bd.tag('Role', :value => node["caen"]["Role"])
            bd.tag('Owner', :value => node["caen"]["Owner"])
            bd.tag('Name', :value => node["opsworks"]["instance"]["hostname"])
        end
    }

# the following commented section is for the v2 sdk, which while the officially supported version,
# doesn't work in opsworks...
#   ec2 = AWS::EC2::Resource.new(region:node["opsworks"]["instance"]["region"])
#   inst = ec2.instance(node["opsworks"]["instance"]["aws_instance_id"])
#   inst.create_tags({ dry_run: false,
#                      tags: [ { key: "Shortcode", value: node["caen"]["Shortcode"],},
#                              { key: "Purpose", value: node["caen"]["Purpose"],},
#                              { key: "Role", value: node["caen"]["Role"],},
#                              { key: "Owner", value: node["caen"]["Owner"],}, ], } )
  end
  action :run
end

