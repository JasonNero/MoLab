extends Node3D

@export var grid_size: Vector2 = Vector2(20, 20)  # Grid dimensions
@export var cell_size: float = 1.0  # Size of each grid cell
@export var grid_color: Color = Color(0.5, 0.5, 0.5, 1.0)  # Grid line color
@export var main_line_interval: int = 5  # Interval for thicker lines
@export var main_line_color: Color = Color(1.0, 1.0, 1.0, 1.0)  # Color for main lines

var immediate_mesh: ImmediateMesh
var material: StandardMaterial3D

func _ready():
    # Create the mesh and material
    immediate_mesh = ImmediateMesh.new()
    material = StandardMaterial3D.new()

    # Configure material
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.vertex_color_use_as_albedo = true
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

    # Create mesh instance
    var mesh_instance = MeshInstance3D.new()
    mesh_instance.mesh = immediate_mesh
    mesh_instance.material_override = material
    add_child(mesh_instance)

    # Generate the grid
    generate_grid()

func generate_grid():
    immediate_mesh.clear_surfaces()
    immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES)

    # Draw horizontal lines
    for z in range(-int(grid_size.y/2), int(grid_size.y/2) + 1):
        var is_main_line_z = z % main_line_interval == 0
        var line_color = main_line_color if is_main_line_z else grid_color

        # Draw line
        immediate_mesh.surface_set_color(line_color)
        immediate_mesh.surface_add_vertex(Vector3(-grid_size.x/2 * cell_size, 0.01, z * cell_size))
        immediate_mesh.surface_add_vertex(Vector3(grid_size.x/2 * cell_size, 0.01, z * cell_size))

    # Draw vertical lines
    for x in range(-int(grid_size.x/2), int(grid_size.x/2) + 1):
        var is_main_line_x = x % main_line_interval == 0
        var line_color = main_line_color if is_main_line_x else grid_color

        # Draw line
        immediate_mesh.surface_set_color(line_color)
        immediate_mesh.surface_add_vertex(Vector3(x * cell_size, 0.01, -grid_size.y/2 * cell_size))
        immediate_mesh.surface_add_vertex(Vector3(x * cell_size, 0.01, grid_size.y/2 * cell_size))

    immediate_mesh.surface_end()
