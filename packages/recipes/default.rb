yum_package 'mysql-connector-java' do
  action :remove
end

remote_file "/var/tmp/mysql-connector-java-5.1.36-1.fc23.noarch.rpm" do
  source "https://s3-ap-northeast-1.amazonaws.com/mytestbucket-nv/mysql-connector-java-5.1.36-1.fc23.noarch.rpm";
  not_if "rpm -qa | grep -q '^mysql-connector-java'"
  notifies :install, "yum_package[mysql-connector-java-new]", :immediately
end

yum_package 'mysql-connector-java-new' do
  source "/var/tmp/mysql-connector-java-5.1.36-1.fc23.noarch.rpm"
  action :install
end
