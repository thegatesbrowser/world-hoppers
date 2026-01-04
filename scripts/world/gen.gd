extends VoxelGeneratorScript

var _channel = VoxelBuffer.CHANNEL_TYPE
var voxels:VoxelBlockyTypeLibrary = preload("res://resources/voxel_block_library.tres")
var iron := preload("res://resources/items/iron_block.tres")
var diamond := preload("res://resources/items/diamond_block.tres")
var possible_ore = [iron,diamond]

const temp_curve = preload("res://resources/noises/temp_curve.tres") as Curve
const curve = preload("res://resources/noises/heightmap_curve.tres") as Curve
const base_curve:Curve = preload("res://resources/noises/heightmap_curve.tres")
const hill_curve:Curve = preload("res://resources/noises/hill.tres")
const cavenoise:FastNoiseLite = preload("res://resources/noises/cave_noise.tres")
const hill_noise:FastNoiseLite = preload("res://resources/noises/hills noise.tres")
var heightmap_noise: FastNoiseLite = FastNoiseLite.new()
var temperature_noise: FastNoiseLite = FastNoiseLite.new()

var last_biome:String = ""

var Bedrock:int = voxels.get_model_index_default("bedrock")
const AIR: int = 0

var biomes : Dictionary = {
	"forest": {
		"heat_range": [0,1,2,3,4,5,6,7,8,9,10],
		"first_layer": voxels.get_model_index_default("grass"),
		"second_layer": voxels.get_model_index_default("dirt"),
		"third_layer": voxels.get_model_index_default("stone"),
		"ore": {
			voxels.get_model_index_default("iron"): {"spawn_chance":0.001},
			voxels.get_model_index_default("diamond"): {"spawn_chance":0.0001},
			},
		"plants": [voxels.get_model_index_default("tall_grass"),voxels.get_model_index_default("tall_flower")],
		"creatures": ["./resources/creatures/fox.tres"],
		"creature_spawn_chance": 0.006
	},
	"desert": {
		"heat_range": [11,12,13,14,15,16,17,18,19,20],
		"first_layer": voxels.get_model_index_default("sand"),
		"second_layer": voxels.get_model_index_default("sand"),
		"third_layer": voxels.get_model_index_default("stone"),
		"ore": {
			voxels.get_model_index_default("iron"): {"spawn_chance":0.001},
			voxels.get_model_index_default("diamond"): {"spawn_chance":0.0001},
			},
		"plants": [voxels.get_model_index_default("reeds")],
		"creatures": [],
		"creature_spawn_chance": 0.006
	},
}
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

const _moore_dirs = [
	Vector3(-1, 0, -1),
	Vector3(0, 0, -1),
	Vector3(1, 0, -1),
	Vector3(-1, 0, 0),
	Vector3(1, 0, 0),
	Vector3(-1, 0, 1),
	Vector3(0, 0, 1),
	Vector3(1, 0, 1)
]

func _init() -> void:
	heightmap_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	heightmap_noise.frequency = 0.01

	temperature_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	temperature_noise.frequency = 0.01
	temperature_noise.seed = 123453

	temp_curve.bake()
	base_curve.bake()
	hill_curve.bake()
	
	
func _generate_block(out_buffer: VoxelBuffer, origin_in_voxels: Vector3i, lod: int) -> void:
	var temp:float
	var block_size := int(out_buffer.get_size().x)
	#var chunk_pos = Vector3(origin_in_voxels.x,origin_in_voxels.y,origin_in_voxels.z)
	var chunk_pos := Vector3(
		origin_in_voxels.x >> 4,
		origin_in_voxels.y >> 4,
		origin_in_voxels.z >> 4)
		
	var rng = RandomNumberGenerator.new()
	rng.seed = _get_chunk_seed_2d(chunk_pos)
	
	for x in range(16):
		for y in range(16):
			for z in range(16):
						  # current issue is that x, y, and z is between 0-15 as seen above in the for loop, when we obviously
				  # have a lot more coordinates in the world

				  # what we do have is the starting point of the currently generating chunk, origin_in_voxels, which we can use to figure out the real coordinate of the voxel we are about to place in this chunk

				  # we will get these "real" coordinates (ugly way)
				
				var real_coordinate_x := origin_in_voxels.x + x
				var real_coordinate_y := origin_in_voxels.y + y
				var real_coordinate_z := origin_in_voxels.z + z
				
				#temp = get_temp(x, z)
				var biome_name = "forest"

				#if last_biome == "":
					#biome_name = get_biome(temp)
				#else:
					#if temp in biomes[last_biome].heat_range:
					#	biome_name = last_biome
					#else:
					#	biome_name = get_biome(temp)
						#last_biome = biome_name
				#print(real_coordinate_y)
				 # these coordinates are now unique, e.g. Minecraft coordinates.
				  # if we check this coordinate for height, we will get the expected behaviour
				  # since it accounts for the position of the chunk we are generating, not just y == 4 in all chunks 
				var real_height = _get_height_at(real_coordinate_x,real_coordinate_z)
				var voxel_tool := out_buffer.get_voxel_tool()
				#print(real_height)
				
				if real_coordinate_y <= real_height:
				# important thing is that we do not set voxels using the real coordinate; the chunk we are generating ONLY cares about coordinates relative to itself, e.g. 0-16, so we use the normal y here
					
					if real_coordinate_y == real_height:
						if rng.randf() < 0.001:
							#var creature = biomes[biome_name].creatures.pick_random().get_path()
							#out_buffer.set_voxel(voxels.get_model_index_default("creature_spawner"),x,y,z,_channel)
							#out_buffer.set_voxel_metadata(Vector3i(x,y,z),creature)
							pass
					
						if rng.randf() <= 0.2:
							var plant_size = biomes[biome_name].plants.size() - 1
							var plant = biomes[biome_name].plants[rng.randi_range(0,plant_size)]
							
							var foliage
						
							foliage = plant
							
							out_buffer.set_voxel(foliage, x, y, z, _channel)
							
					#voxel_tool.paste(Vector3(x,y,z),test_structure.voxels,_channel)
					#voxel_tool.paste_masked(Vector3(x,y,z),test_structure.voxels,_channel,_channel,voxels.get_model_index_default("cave_air"))
						
						
					if real_coordinate_y == real_height - 1:
						out_buffer.set_voxel(biomes[biome_name].first_layer, x, y, z,_channel )# x, y, and z are all between 0-15
					if real_coordinate_y < real_height - 1:
						out_buffer.set_voxel(biomes[biome_name].second_layer, x, y, z,_channel )# x, y, and z are all between 0-15
					if real_coordinate_y < real_height - 2:
							out_buffer.set_voxel(biomes[biome_name].third_layer, x, y, z,_channel )# x, y, and z are all between 0-15

							var ores:Dictionary = biomes[biome_name].ore
							var ore_size =  ores.keys().size() - 1
							var key = (ores.keys()[rng.randi_range(0,ore_size)]) ## key is voxel id
							var ore = ores[key]
							
							if rng.randf() < ore.spawn_chance:
								
								voxel_tool.set_voxel(Vector3i(x, y, z),key)
								
								
					var cave = cave(real_coordinate_x,real_coordinate_z,real_coordinate_y)
					if cave:
						#caves.append(Vector3(real_coordinate_x,real_coordinate_y,real_coordinate_z))
						out_buffer.set_voxel(voxels.get_model_index_default("air"), x, y, z,_channel )# x, y, and z are all between 0-15
				#			
				else:
					out_buffer.set_voxel(voxels.get_model_index_default("air"),x,y,z,_channel)
			
					
					## Water
					#if real_height < 0 and origin_in_voxels.y < 0:
						#var start_relative_height := 0
						#if real_height - origin_in_voxels.y > 0:
							#start_relative_height = real_height - origin_in_voxels.y 
						#out_buffer.fill_area(voxels.get_model_index_default("water_full"),
							#Vector3(x, start_relative_height, z), 
							#Vector3(x + 1, block_size -1, z + 1), _channel)
						#if origin_in_voxels.y + block_size == 0:
							#out_buffer.set_voxel(voxels.get_model_index_default("water_top"),x,block_size - 1,z)
				
			
					
func _get_height_at(x: int, z: int) -> int:
	var hill_noise_value:float =  0.5 + 0.5 * hill_noise.get_noise_2d(x, z)
	var base_noise_value:float =  0.5 + 0.5 * heightmap_noise.get_noise_2d(x, z)
	
	return int(base_curve.sample_baked(base_noise_value) + hill_curve.sample_baked(hill_noise_value))

func cave(x:int,y:int,z:int) -> bool:
	var t = cavenoise.get_noise_3d(x, y, z)
	if t > 0:
		return true
	else:
		return false
					
static func _get_chunk_seed_2d(cpos: Vector3) -> int:
	return int(cpos.x) ^ (31 * int(cpos.z))

func get_biome(temp: int) -> String:
	for biome_name in biomes:
		var biome = biomes[biome_name]
		if temp in biome.heat_range:
			return biome_name

	return "forest"  # Default biome if none match
	

func get_temp(x: int, z: int) -> int:
	var temperature =  0.5 + 0.5 * temperature_noise.get_noise_2d(x, z)
	return int(temp_curve.sample_baked(temperature))
