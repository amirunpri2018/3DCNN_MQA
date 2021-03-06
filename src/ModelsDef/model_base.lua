local requireRel
if arg and arg[0] then
    package.path = arg[0]:match("(.-)[^\\/]+$") .. "?.lua;" .. package.path
    requireRel = require
elseif ... then
    local d = (...):match("(.-)[^%.]+$")
    function requireRel(module) return require(d .. module) end
end

require 'nn'
require 'cunn';
torch.setdefaulttensortype('torch.FloatTensor')


cModelBase = {}
cModelBase.__index = cModelBase

function cModelBase.new(self, input_options, net)
	setmetatable(cModelBase, self)
    self.__index = self

	self.input_options = input_options
	self.net = net
	return cModelBase
end

function cModelBase.initialize_cuda(self, device_num)
	self.device_num = device_num
	self.init_gpu_mem = cutorch.getDeviceProperties(self.device_num)['freeGlobalMem']
	self.net = self.net:cuda()
	self.gpu_mem = cutorch.getDeviceProperties(self.device_num)['freeGlobalMem']
end

function cModelBase.get_network_size(self)
	self.gpu_mem = cutorch.getDeviceProperties(self.device_num)['freeGlobalMem']
	return (self.gpu_mem - self.init_gpu_mem)/1000000
end

function cModelBase.load_model(self, dir_path)	
	for i=1,self.net:size() do
		local layer = self.net:get(i)
		if not( string.find(tostring(layer),'nn.VolumetricConvolution')==nil) then
			layer.weight:copy(torch.load(dir_path..'/VC'..tostring(i)..'W.dat'))
			layer.bias:copy(torch.load(dir_path..'/VC'..tostring(i)..'B.dat'))
		end
		if not( string.find(tostring(layer),'nn.Linear') == nil ) then
			layer.weight:copy(torch.load(dir_path..'/FC'..tostring(i)..'W.dat'))
			layer.bias:copy(torch.load(dir_path..'/FC'..tostring(i)..'B.dat'))
		end
		if not( string.find(tostring(layer),'nn.VolumetricBatchNormalizationMy') == nil ) then
			if layer.affine then
				layer.weight:copy(torch.load(dir_path..'/BN'..tostring(i)..'W.dat'))
				layer.bias:copy(torch.load(dir_path..'/BN'..tostring(i)..'B.dat'))
				layer.running_mean:copy(torch.load(dir_path..'/BN'..tostring(i)..'RM.dat'))
				layer.running_std:copy(torch.load(dir_path..'/BN'..tostring(i)..'RS.dat'))
			end
		end
	end
end

function cModelBase.save_model(self, dir_path)
	for i=1,self.net:size() do
		local layer = self.net:get(i)
		if not( string.find(tostring(layer),'nn.VolumetricConvolution')==nil) then
			torch.save(dir_path..'/VC'..tostring(i)..'W.dat', layer.weight:float())
			torch.save(dir_path..'/VC'..tostring(i)..'B.dat', layer.bias:float())
		end
		if not( string.find(tostring(layer),'nn.Linear') == nil ) then
			torch.save(dir_path..'/FC'..tostring(i)..'W.dat', layer.weight:float())
			torch.save(dir_path..'/FC'..tostring(i)..'B.dat', layer.bias:float())
		end
		if not( string.find(tostring(layer),'nn.VolumetricBatchNormalizationMy') == nil ) then
			if layer.affine then
				torch.save(dir_path..'/BN'..tostring(i)..'W.dat', layer.weight:float())
				torch.save(dir_path..'/BN'..tostring(i)..'B.dat', layer.bias:float())
				torch.save(dir_path..'/BN'..tostring(i)..'RM.dat', layer.running_mean:float())
				torch.save(dir_path..'/BN'..tostring(i)..'RS.dat', layer.running_std:float())
				print(layer.weight:float())
			end
		end
	end
end

function cModelBase.print_model(self)
	local input_size = {self.input_options.num_channels, 
	self.input_options.input_size, self.input_options.input_size, self.input_options.input_size}
	
	print('Layer\t\tOutput dimensions')
	print('Input\t\t'..tostring(input_size[1]).."x"..tostring(input_size[2]).."x"..tostring(input_size[3]).."x"..tostring(input_size[4]))
	local output_size = input_size
	for i=1,self.net:size() do
		local layer = self.net:get(i)
		-- print(tostring(layer))
		if not( string.find(tostring(layer), 'nn.VolumetricConvolution')==nil) then
			local output_x = math.floor((input_size[2] + 2*layer.padT - layer.kT) / layer.dT + 1)
			local output_y = math.floor((input_size[3] + 2*layer.padW - layer.kW) / layer.dW + 1)
			local output_z = math.floor((input_size[4] + 2*layer.padH - layer.kH) / layer.dH + 1)
			
			input_size = {layer.nOutputPlane, output_x, output_y, output_z}
			print(tostring(i)..':VolConv\t\t'..tostring(input_size[1]).."x"..tostring(input_size[2]).."x"..tostring(input_size[3]).."x"..tostring(input_size[4]))
		end
		if not( string.find(tostring(layer), 'nn.VolumetricMaxPooling')==nil) then
			local output_x = math.floor((input_size[2] + 2*layer.padT - layer.kT) / layer.dT + 1)
			local output_y = math.floor((input_size[3] + 2*layer.padW - layer.kW) / layer.dW + 1)
			local output_z = math.floor((input_size[4] + 2*layer.padH - layer.kH) / layer.dH + 1)
			input_size = {input_size[1], output_x, output_y, output_z}
			print(tostring(i)..':MaxPool\t\t'..tostring(input_size[1]).."x"..tostring(input_size[2]).."x"..tostring(input_size[3]).."x"..tostring(input_size[4]))
		end
		if tostring(layer) == 'nn.VolumetricBatchNormalization' then
			print(tostring(i)..':BatchNorm')
		end
		if tostring(layer) == 'nn.ReLU' then
			print(tostring(i)..':ReLU')
		end
		if not( string.find(tostring(layer),'nn.Linear') == nil ) then
			print(tostring(i)..':Linear\t\t'..layer.weight:size()[2]..'->'..layer.weight:size()[1])
		end
	end
end

function cModelBase.MSRinit(self)
	local function init(name)
		for k,v in pairs(self.net:findModules(name)) do
			local fan_in = 1.0
			local fan_out = 1.0
			if name=='nn.VolumetricConvolution' or name=='cunn.VolumetricConvolution' then
				fan_in = v.kW*v.kH*v.kT*v.nInputPlane
				fan_out = v.kW*v.kH*v.kT*v.nOutputPlane
			elseif name == 'nn.Linear' or name == 'cunn.Linear' then
				fan_in = v.weight:size(1)
				fan_out = v.weight:size(2)
			end
			--v.weight:normal(0,math.sqrt(1/(3*fan_in)))
			v.weight:normal(0,math.sqrt(2/fan_out))
			v.bias:zero()
		end
	end
	init'nn.VolumetricConvolution'
	init'cunn.VolumetricConvolution'
	init'nn.Linear'
	init'cunn.Linear'
end
