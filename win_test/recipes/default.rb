Chef::Log.level = :debug

Chef::Log.info("******Creating a data directory.******")

directory 'C:\data' do
  rights :full_control, 'WORKGROUP\vernitin'
  inherits false
  action :create
end
 
layer = search(:aws_opsworks_instance, "layer_ids:*").first

Chef::Log.info("********** '#{layer}'**********") 

#Chef::Log.info("Node OW Layer: '#{node[:opsworks][:layers]}' ")

layers = search(:aws_opsworks_layer)

layers.each do |layr|
        Chef::Log.info("Layer Name: '#{layr[:name]}' ")
	Chef::Log.info(" *** The deployed layer shortname is #{layr[:shortname]} ****")
end
