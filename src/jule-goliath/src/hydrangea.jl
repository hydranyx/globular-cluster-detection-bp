module hydrangea
using Distributed
using Pkg
if nworkers() > 1 || nprocs() > 1
    @everywhere using Pkg
    @everywhere Pkg.activate(".")
    @everywhere Pkg.instantiate()
    @everywhere using CSV
    @everywhere using DataStructures
    @everywhere using DataFrames
    @everywhere using Statistics
    @everywhere using StatsBase
    @everywhere using LinearAlgebra
    @everywhere using Glob
    @everywhere using NearestNeighbors
else
    using Pkg
    Pkg.activate(".")
    Pkg.instantiate()
    using CSV
    using DataStructures
    using DataFrames
    using Statistics
    using StatsBase
    using LinearAlgebra
    using Glob
    using NearestNeighbors
end

# Constants #
NUMBER_OF_NEIGHBORS = 20 # Number of neighbors to consider per star.
N_ITER = 5
N_A = 30
N_S = 2000

C = 2 #check what is an appropriate value for this
RHO = 0.1 #parameter evaporation rate
GAMMA = 0.9 #controling effect on the step
EPSILON = 0.000000000001 # a very small non-zero value TODO this might break something

PHEROMONE_THRESHOLD = 1.0
COORDINATE_ROUNDING_NUMBER = 1
############

function k_nearest_neighbors(data_frame, k)
    data_matrix = convert(Matrix, select(data_frame, [:ra, :dec, :distance]))'
    kd_tree = KDTree(data_matrix)

    indices, distances = knn(kd_tree, data_matrix, k+1, true)
    indices = map(v -> v[2:end], indices)
    distances = map(v -> v[2:end], distances)
    stars_neighbors = []

    for (neighbor_indices, neighbor_distances) in zip(indices, distances)
        sorted_neighbors = zip(neighbor_indices, neighbor_distances) |> collect # pipe result into collect
        sorted_neighbors = OrderedDict(sorted_neighbors)
        push!(stars_neighbors, sorted_neighbors)
    end

    return stars_neighbors
end

""" Add the `k` nearest neighbors to the provided `data_frame`. """
function add_neighbors!(data_frame)
    data = select(data_frame, [:ra, :dec, :distance])
    neighbors = k_nearest_neighbors(data_frame, NUMBER_OF_NEIGHBORS)
    # insert neighbors in data_frame
    insertcols!(data_frame, :neighbors => neighbors)
end

""" Computes the weight for each neighbor. """
function compute_weights!(data_frame)
    columns = [:ra, :dec, :pmra, :pmdec, :distance]
    df_columns = select(data_frame, columns)

    all_weights = []
    length = nrow(data_frame)
    for row in eachrow(data_frame)
        nbrs = row[:neighbors]
        rows = collect(keys(nbrs))
        nbrs_data = data_frame[rows, columns]

        # compute the distance to the tangent space
        μ = mapcols(mean, nbrs_data)
        X_standard = convert(Array, nbrs_data .- μ)
        X_pca      = svd(X_standard)
        U, Σ, V    = X_pca
        Σ = Σ / sum(Σ)
        U, V = svd_flip(U, V')

        magnitudes_data = norm.(eachrow(X_standard))
        normalized_covariance = X_standard ./ magnitudes_data

        #compute the weight based on the distance to the tangent space
        eigen_value = Σ
        eigen_vector = V
        weights = abs.(normalized_covariance * eigen_vector') * eigen_value
        weights = Dict(zip(rows, weights))
        push!(all_weights, weights)
    end

    insertcols!(data_frame, :weights => all_weights)
end

function svd_flip(u, v, u_based_decision=true)
    signs = if u_based_decision
        # columns of u, rows of v
        max_abs = argmax(abs.(u), dims=1)
        sign.(u[max_abs])
    else
        # rows of v, columns of u
        max_abs = argmax(abs.(v), dims=2)
        sign.(v[max_abs])
    end
    u .*= signs
    v .*= signs'
    return u, v
end

function next_position(current_star, data_frame)
    # initialize the values NOTE: check if done correct
    weights = current_star[:weights]
    nbrs = current_star[:neighbors]
    neighbors = collect(keys(nbrs))

    # normalizing the pheromones
    f_hats = Dict()
    pheromones = data_frame[neighbors, :pheromone]
    sum_of_pheromones = sum(pheromones)
    for x_j in neighbors
        if sum_of_pheromones == 0
            f_hats[x_j] = EPSILON
        else
            f_hats[x_j] = data_frame[x_j, :pheromone] / sum_of_pheromones
        end
    end

    #calculating the transition probabilities per star
    probabilities = Dict()
    denom = sum(map(x_k -> (weights[x_k]^GAMMA) * (f_hats[x_k]^(1-GAMMA)),neighbors))
    for x_j in neighbors
        numer = (weights[x_j]^GAMMA) * (f_hats[x_j]^(1-GAMMA))
        probabilities[x_j] = numer / denom
    end

    next_index = sample(collect(keys(probabilities)), Weights([el for el in values(probabilities)]))
    return eachrow(data_frame)[next_index]
end

function random_starting_position(data_frame)
    return rand(eachrow(data_frame))
end

function update_pheromone!(data_frame)
    for row in eachrow(data_frame)
        previous_pheromone = row[:pheromone]
        number_of_visitations = row[:visitations]
        row[:pheromone] = (C * (number_of_visitations/(N_A * N_S))) + ((1-RHO) * previous_pheromone)
    end
end

function ant_algorithm!(data_frame)
    insertcols!(data_frame, :pheromone => 0.0)
    insertcols!(data_frame, :visitations => 0)
    insertcols!(data_frame, :total_visitations => 0)

    for t in 1:N_ITER
        println("iteration: $t")
        data_frame[!, :visitations] .= 0
        for a in 1:N_A
            # x_i is a row from the dataframe for that star
            x_i = random_starting_position(data_frame)
            x_i[:visitations] += 1
            x_i[:total_visitations] += 1
            for s in 1:N_S
                x_i = next_position(x_i, data_frame)
                x_i[:visitations] += 1
                x_i[:total_visitations] += 1
            end
        end

        #Update pheromone by Eq. (2.4):
        update_pheromone!(data_frame)
    end
end

function run_for_all(input_glob, output_dir)
    idx = 1

    println("Running across all data:")
    input_paths = [data_path for data_path in glob(input_glob)]
    Threads.@threads for data_path in input_paths
    # for data_path in input_paths
        # make the data frame
        data_frame = CSV.read(data_path, DataFrame)
        println("Length data_path $idx: $(nrow(data_frame))")

        # increase the index
        idx += 1

        begin
            println("Adding neighbors")
            add_neighbors!(data_frame)
            println("Computing weights")
            compute_weights!(data_frame)
            println("Running ant algorithm")
            ant_algorithm!(data_frame)
        end

        file_name = basename(data_path)
        output_path = "$output_dir/$file_name"
        println("Saving results to '$output_path'")
        CSV.write(output_path, data_frame)
    end
end

function iterate_clusters_rec!(data_frame, current_cluster, neighbors, clusters, processed_stars)
    for star in neighbors
        if !haskey(processed_stars, star)
            if current_cluster === nothing
				# initialize new cluster
                new_cluster_index = length(clusters) + 1
                push!(clusters, Set(star))
				processed_stars[star] = new_cluster_index
                iterate_clusters_rec!(data_frame, new_cluster_index, data_frame[star, :neighbors], clusters, processed_stars)
            end
        else
			# add the star to existing cluster
			push!(clusters[current_cluster], star)
			processed_stars[star] = current_cluster
			iterate_clusters_rec!(data_frame, current_cluster, data_frame[star, :neighbors], clusters, processed_stars)
        end
    end
end

function main_ant()
    rasters = [
        "a1-rastered",
        "a2-rastered",
        "a3-rastered",
        "a4-rastered",
        "a2-4x4-rastered"
    ]
    # rasters = ["linked"]

    for raster in rasters
    	input = "resources/input/$raster/*.csv"
    	output_dir = "resources/output/$raster"
    	mkpath(output_dir)
    	
    	@time run_for_all(input, output_dir)	
    end    
end

end # module

hydrangea.main_ant()
