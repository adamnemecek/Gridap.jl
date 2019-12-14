module FaceLabelingsTests

using Test
using Gridap.Helpers
using Gridap.Arrays
using Gridap.ReferenceFEs
using Gridap.Geometry
using Gridap.Geometry: DiscreteModelMock

model = DiscreteModelMock()

d_to_num_dfaces = [num_vertices(model), num_edges(model), num_cells(model)]

labels = FaceLabeling(d_to_num_dfaces)

@test num_tags(labels) == 0
@test num_entities(labels) == 0
@test num_faces(labels,0) == num_faces(model,0)
@test num_faces(labels,1) == num_faces(model,1)
@test num_faces(labels,2) == num_faces(model,2)
@test num_vertices(labels) == num_vertices(model)
@test num_edges(labels) == num_edges(model)
@test num_facets(labels) == num_facets(model)
@test num_faces(labels) == num_faces(model)
@test num_dims(labels) == num_dims(model)
@test num_cell_dims(labels) == num_cell_dims(model)
@test get_face_entity(labels,0) === labels.d_to_dface_to_entity[0+1]
@test get_face_entity(labels,1) === labels.d_to_dface_to_entity[1+1]
@test get_face_entity(labels,2) === labels.d_to_dface_to_entity[2+1]
@test get_face_entity(labels) == vcat(labels.d_to_dface_to_entity...)

get_face_entity(labels,0) .= get_isboundary_face(model,0) .+ 1
get_face_entity(labels,1) .= get_isboundary_face(model,1) .+ 1
get_face_entity(labels,2) .= get_isboundary_face(model,2) .+ 1

add_tag!(labels,"interior",[1,])
add_tag!(labels,"boundary",[2,])
add_tag_from_tags!(labels,"all",["interior","boundary"])
@test num_entities(labels) == 2
@test num_tags(labels) == 3
@test get_tag_name(labels,1) == "interior"
@test get_tag_name(labels,3) == "all"
@test get_tag_from_name(labels,"interior") == 1
@test get_tag_from_name(labels,"all") == 3

end # module