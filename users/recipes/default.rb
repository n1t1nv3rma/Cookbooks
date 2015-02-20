#
# Cookbook Name:: users
# Recipe:: default
#
# Copyright (c) 2015 The Authors, All Rights Reserved.
#users = ["nverma" => Main User, "nitin" => Secondary User]
#users = ["nverma","nitin"]
users = "#{node['users']['names']}"

if platform?("centos","redhat")
 users.each do |myuser|
   user myuser do 
     home "/home/#{myuser}"
     shell "/bin/bash"
     #comment mycomment
     password "$1$S6Z1FFQL$7SGw/luaw8uFRaJTxK2sN."
   end
 end
else
 log "Error: unsupported OS"
end
