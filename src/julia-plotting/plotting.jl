### A Pluto.jl notebook ###
# v0.17.1

using Markdown
using InteractiveUtils

# ╔═╡ e45eda6e-3d26-4ade-a729-685ccfa0511e
begin
	using JSON
	using DataFrames
	using ColorSchemes
	using Gadfly
	using PlutoUI
end

# ╔═╡ 5cf7d1c7-f625-468d-97b0-ee1f78699141
begin
	path = "../rusty-hydra/resources/final"
	run = "01"
	
	a1 = "$path/run-$run/5-statistics/a1/stats.json"
	a2 = "$path/run-$run/5-statistics/a2/stats.json"
	a3 = "$path/run-$run/5-statistics/a3/stats.json"
	a4 = "$path/run-$run/5-statistics/a4/stats.json"
	a2_4x4 = "$path/run-$run/5-statistics/a2-4x4/stats.json"

	output_path = "output/run-$run"
	mkpath(output_path)
end;

# ╔═╡ bb1c80c3-3f02-4dda-bca4-bd6a0f943a6b
areas = map(file -> DataFrame(JSON.parsefile(file)), [a1, a2, a3, a4, a2_4x4]);

# ╔═╡ c4f88cf6-08f7-404f-8073-0f1b317e698c
function extract_key((value_key, value_type), value_name, area_name, area)
	D = DataFrame(
		Value = map(x->parse(value_type, x), collect(keys(area[!, value_key][1]))),
		Area = area_name,
		Frequency = collect(values(area[!, value_key][1])),
		Proportion = (collect(values(area[!, value_key][1])) * 100) / sum(values(area[!, value_key][1]))
	)
	select(D, "Value" => value_name, :Area, :Frequency, :Proportion => "Frequency (%)")
end

# ╔═╡ 02249d9d-a1ec-4b72-89cc-b7f52b40031d
begin
	# Setup a common font for gadfly plots
	latex_fonts = Theme(
		major_label_font="CMU Serif", major_label_font_size=10pt,
    	minor_label_font="CMU Serif", minor_label_font_size=10pt,
		key_title_font="CMU Serif", key_title_font_size=12pt,
		key_label_font="CMU Serif", key_label_font_size=10pt
	)
	large_latex_fonts = Theme(
		major_label_font="CMU Serif", major_label_font_size=13pt,
    	minor_label_font="CMU Serif", minor_label_font_size=13pt,
		key_title_font="CMU Serif", key_title_font_size=15pt,
		key_label_font="CMU Serif", key_label_font_size=13pt
	)

	# Common color palette
	palette = ["tomato","royalblue", "darkorchid2","springgreen3"]
	palette5 = ["tomato","royalblue", "#404040", "darkorchid2","springgreen3"]


	# Pick plot size
	set_default_plot_size(20cm, 12cm)
end;

# ╔═╡ d02e6ab3-dc40-49c2-a64e-339d767d79a6
Gadfly.with_theme(latex_fonts) do
	extraction = ("magnitude_distribution", Int64)
	name = "Apparent Magnitude"
	output_name = "apparent-magnitude"
	label = "$name"
	
	d1 = extract_key(extraction, name, "Area 1", areas[1])
	d2 = extract_key(extraction, name, "Area 2", areas[2])
	d3 = extract_key(extraction, name, "Area 3", areas[3])
	d4 = extract_key(extraction, name, "Area 4", areas[4])
	
	D = sort(outerjoin(d1, d2, d3, d4, on=[:Area, :Frequency, :"Frequency (%)", name]))

	draw(SVG("$output_path/$output_name.svg"), plot(D,
		 x = :Area,
		 xgroup = name,
		 y = :Frequency,
		 Geom.subplot_grid(Geom.bar(position=:dodge), Guide.xticks(label=false)),
		 color = :Area, 
		 Scale.x_discrete,
		 Guide.xlabel(label),
		 Scale.y_log10,
		 Scale.color_discrete_manual(palette...)
	))
	
	draw(SVG("$output_path/$output_name-proportional.svg"), plot(D,
		 x = :Area, 
		 xgroup = name,
		 y = :"Frequency (%)",
		 Geom.subplot_grid(Geom.bar(position=:dodge), Guide.xticks(label=false)),
		 color = :Area, 
		 Scale.x_discrete,
		 Guide.xlabel(label),
		 Scale.color_discrete_manual(palette...)
	))
end;

# ╔═╡ 88986ac1-ee54-43cd-a017-9c36ce453b8a
Gadfly.with_theme(latex_fonts) do
	set_default_plot_size(20cm, 12cm)
	extraction = ("pheromone_distribution", Float64)
	name = "Pheromone Value"
	output_name = "pheromone"
	label = "$name"

	d1 = extract_key(extraction, name, "Area 1", areas[1])
	d2 = extract_key(extraction, name, "Area 2: 2x2", areas[2])
	d3 = extract_key(extraction, name, "Area 2: 4x4", areas[5])
	d4 = extract_key(extraction, name, "Area 3", areas[3])
	d5 = extract_key(extraction, name, "Area 4", areas[4])

	d1 = select(d1, name, :Area, :"Frequency (%)")
	d2 = select(d2, name, :Area, :"Frequency (%)")
	d3 = select(d3, name, :Area, :"Frequency (%)")
	d4 = select(d4, name, :Area, :"Frequency (%)")
	d5 = select(d5, name, :Area, :"Frequency (%)")
	
	D = outerjoin(d1, d2, d3, d4, d5, on=[:Area, :"Frequency (%)", name])

	# draw(SVG("$output_path/$output_name.svg"), plot(D,
	# 	 x = name,
	# 	 xgroup = :Area,
	# 	 y = :Frequency,
	# 	 Geom.density,
	# 	 color = :Area,
	# 	 Guide.ylabel("Density"),
	# 	 Guide.xlabel(label),
	# 	 Coord.cartesian(xmin=0),
	# 	 Scale.alpha_continuous,
	# 	 Scale.y_log10,
	# 	 Scale.color_discrete_manual(palette5...),
	# 	 Theme(bar_spacing=0.5mm)
	# ))
	
	draw(SVG("$output_path/$output_name-proportional.svg"), plot(D,
		 x = name,
		 xgroup = :Area,
		 y = :"Frequency (%)",
		 Geom.density,
		 color = :Area, 
		 Guide.xlabel(label),
		 Guide.ylabel("Density"),
		 Scale.alpha_continuous,
		 Coord.cartesian(xmin=0),
		 Scale.color_discrete_manual(palette5...),
		 Theme(bar_spacing=0.5mm)
	))

	sum(D[!, :"Frequency (%)"])
end

# ╔═╡ af8f37e4-4f8c-4c7f-b800-eebd5ddd5163
Gadfly.with_theme(latex_fonts) do
	set_default_plot_size(20cm, 12cm)
	extraction = ("parallax_distribution", Float64)
	name = "Parallax"
	output_name = "parallax"
	label = "$name (mas)"
	
	d1 = extract_key(extraction, name, "Area 1", areas[1])
	d2 = extract_key(extraction, name, "Area 2", areas[2])
	d3 = extract_key(extraction, name, "Area 3", areas[3])
	d4 = extract_key(extraction, name, "Area 4", areas[4])
	
	D = outerjoin(d1, d2, d3, d4, on=[:Area, :Frequency, :"Frequency (%)", name])

	draw(SVG("$output_path/$output_name.svg"), plot(D,
		 x = name,
		 xgroup = :Area,
		 y = :Frequency,
		 Geom.density,
		 Coord.cartesian(xmin = 0),
		 color = :Area, 
		 Guide.ylabel("Density"),
		 Guide.xlabel(label),
		 Guide.xticks(ticks=[0.01, 50:50:700...]),
		 Scale.x_continuous(labels=number-> number == 0.01 ? "$number" : "$(convert(Int64, number))"),
		 Scale.color_discrete_manual(palette...)
	))
		
	draw(SVG("$output_path/$output_name-proportional.svg"), plot(D,
		 x = name,
		 xgroup = :Area,
		 y = :"Frequency (%)",
		 Coord.cartesian(xmin = floor(min(D[!, :Parallax]...))),
		 Geom.density,
		 color = :Area, 
		 Guide.xlabel(label),
		 Guide.ylabel("Density"),
		 Scale.alpha_continuous,
		 Scale.color_discrete_manual(palette...)
	))
end;

# ╔═╡ d0dd3832-ff07-4e64-9961-d9e4123ac2ea
Gadfly.with_theme(latex_fonts) do
	extraction = ("pmra_distribution", Float64)
	name = "Proper Motion Right Ascension"
	output_name = "pmra"
	label = "$name (mas/yr)"
	
	d1 = extract_key(extraction, name, "Area 1", areas[1])
	d2 = extract_key(extraction, name, "Area 2", areas[2])
	d3 = extract_key(extraction, name, "Area 3", areas[3])
	d4 = extract_key(extraction, name, "Area 4", areas[4])
	
	D = outerjoin(d1, d2, d3, d4, on=[:Area, :Frequency, :"Frequency (%)", name])

	draw(SVG("$output_path/$output_name.svg"), plot(D,
		 x = name,
		 xgroup = :Area,
		 y = :Frequency,
		 Geom.density,
		 color = :Area, 
		 Guide.xlabel(label),
		 Guide.ylabel("Density"),
		 # Scale.alpha_continuous,
		 # Scale.x_log10,
		 Scale.y_log10,
		 Scale.color_discrete_manual(palette...)
	))
	
	draw(SVG("$output_path/$output_name-proportional.svg"), plot(D,
		 x = name,
		 xgroup = :Area,
		 y = :"Frequency (%)",
		 Geom.density,
		 color = :Area, 
		 Guide.xlabel(label),
		 Guide.ylabel("Density"),
		 # Scale.alpha_continuous,
		 # Scale.x_log10,
		 Scale.color_discrete_manual(palette...)
	))
end;

# ╔═╡ ac02a3ef-a937-4d3b-a0f6-b1f3f1eb0bf3
Gadfly.with_theme(latex_fonts) do
	extraction = ("pmdec_distribution", Float64)
	name = "Proper Motion Declination"
	output_name = "pmdec"
	label = "$name (mas/yr)"
	
	d1 = extract_key(extraction, name, "Area 1", areas[1])
	d2 = extract_key(extraction, name, "Area 2", areas[2])
	d3 = extract_key(extraction, name, "Area 3", areas[3])
	d4 = extract_key(extraction, name, "Area 4", areas[4])
	
	set_default_plot_size(20cm, 12cm)
	D = outerjoin(d1, d2, d3, d4, on=[:Area, :Frequency, :"Frequency (%)", name])

	draw(SVG("$output_path/$output_name.svg"), plot(D,
		 x = name,
		 xgroup = :Area,
		 y = :Frequency,
		 Geom.density,
		 color = :Area, 
		 Guide.xlabel(label),
		 Guide.ylabel("Density"),
		 # Scale.alpha_continuous,
		 # Scale.x_log10,
		 Scale.y_log10,
		 Scale.color_discrete_manual(palette...)
	))
	
	draw(SVG("$output_path/$output_name-proportional.svg"), plot(D,
		 x = name,
		 xgroup = :Area,
		 y = :"Frequency (%)",
		 Geom.density,
		 color = :Area, 
		 Guide.xlabel(label),
		 Guide.ylabel("Density"),
		 # Scale.alpha_continuous,
		 # Scale.x_log10,
		 Scale.color_discrete_manual(palette...)
	))
end;

# ╔═╡ e456cab4-a779-464b-8ef7-c80cdc922789
Gadfly.with_theme(large_latex_fonts) do
	output_name = "proper-motion"
	
	extraction = ("pmra_distribution", Float64)
	name = "Proper Motion Right Ascension"
	label = "$name (mas/yr)"
	
	d1 = extract_key(extraction, name, "Area 1", areas[1])
	d2 = extract_key(extraction, name, "Area 2", areas[2])
	d3 = extract_key(extraction, name, "Area 3", areas[3])
	d4 = extract_key(extraction, name, "Area 4", areas[4])
	
	set_default_plot_size(30cm, 12cm)
	D_pmra = outerjoin(d1, d2, d3, d4, on=[:Area, :Frequency, :"Frequency (%)", name])
	plot_pmra =  plot(D_pmra,
		 x = name,
		 xgroup = :Area,
		 Coord.cartesian(xmin = floor(min(D_pmra[!, "Proper Motion Right Ascension"]...)) , ymax=0.015),
		 Geom.density,
		 color = :Area, 
		 Guide.xlabel(label),
		 Guide.ylabel("Density"),
		 Scale.y_log10,
		 Scale.color_discrete_manual(palette...),
		 Theme(key_position = :none, large_latex_fonts)
	)

	extraction = ("pmdec_distribution", Float64)
	name = "Proper Motion Declination"
	label = "$name (mas/yr)"
	
	d1 = extract_key(extraction, name, "Area 1", areas[1])
	d2 = extract_key(extraction, name, "Area 2", areas[2])
	d3 = extract_key(extraction, name, "Area 3", areas[3])
	d4 = extract_key(extraction, name, "Area 4", areas[4])
	
	D_pmdec = outerjoin(d1, d2, d3, d4, on=[:Area, :Frequency, :"Frequency (%)", name])


	plot_pmdec =  plot(D_pmdec,
		 x = name,
		 xgroup = :Area,
		 Coord.cartesian(xmin = floor(min(D_pmra[!, "Proper Motion Right Ascension"]...))),
		 Geom.density,
		 color = :Area, 
		 Guide.xlabel(label),
         Guide.ylabel("Density"),
		 Scale.y_log10,
		 Scale.color_discrete_manual(palette...),
	)
	draw(SVG("$output_path/$output_name.svg"), hstack(plot_pmra, plot_pmdec))
end;

# ╔═╡ c246a0fc-36e9-46e8-b9ff-12c87d25e022
begin
	extraction = ("pmra_distribution", Float64)
	name = "Proper Motion Right Ascension"
	label = "$name (mas/yr)"
	
	d1 = extract_key(extraction, name, "Area 1", areas[1])
	d2 = extract_key(extraction, name, "Area 2", areas[2])
	d3 = extract_key(extraction, name, "Area 3", areas[3])
	d4 = extract_key(extraction, name, "Area 4", areas[4])

    D_pmra = sort(outerjoin(d1, d2, d3, d4, on=[:Area, :Frequency, :"Frequency (%)", name]))
end

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
ColorSchemes = "35d6a980-a343-548e-a6ea-1d62b119f2f4"
DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
Gadfly = "c91e804a-d5a3-530f-b6f0-dfbca275c004"
JSON = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"

[compat]
ColorSchemes = "~3.15.0"
DataFrames = "~1.2.2"
Gadfly = "~1.3.4"
JSON = "~0.21.2"
PlutoUI = "~0.7.19"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

[[AbstractFFTs]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "485ee0867925449198280d4af84bdb46a2a404d0"
uuid = "621f4979-c628-5d54-868e-fcf4e3e8185c"
version = "1.0.1"

[[AbstractPlutoDingetjes]]
deps = ["Pkg"]
git-tree-sha1 = "0bc60e3006ad95b4bb7497698dd7c6d649b9bc06"
uuid = "6e696c72-6542-2067-7265-42206c756150"
version = "1.1.1"

[[Adapt]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "84918055d15b3114ede17ac6a7182f68870c16f7"
uuid = "79e6a3ab-5dfb-504d-930d-738a2a938a0e"
version = "3.3.1"

[[ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"

[[Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[AxisAlgorithms]]
deps = ["LinearAlgebra", "Random", "SparseArrays", "WoodburyMatrices"]
git-tree-sha1 = "66771c8d21c8ff5e3a93379480a2307ac36863f7"
uuid = "13072b0f-2c55-5437-9ae7-d433b7a33950"
version = "1.0.1"

[[Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[CategoricalArrays]]
deps = ["DataAPI", "Future", "Missings", "Printf", "Requires", "Statistics", "Unicode"]
git-tree-sha1 = "c308f209870fdbd84cb20332b6dfaf14bf3387f8"
uuid = "324d7699-5711-5eae-9e2f-1d82baa6b597"
version = "0.10.2"

[[ChainRulesCore]]
deps = ["Compat", "LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "f885e7e7c124f8c92650d61b9477b9ac2ee607dd"
uuid = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
version = "1.11.1"

[[ChangesOfVariables]]
deps = ["LinearAlgebra", "Test"]
git-tree-sha1 = "9a1d594397670492219635b35a3d830b04730d62"
uuid = "9e997f8a-9a97-42d5-a9f1-ce6bfc15e2c0"
version = "0.1.1"

[[ColorSchemes]]
deps = ["ColorTypes", "Colors", "FixedPointNumbers", "Random"]
git-tree-sha1 = "a851fec56cb73cfdf43762999ec72eff5b86882a"
uuid = "35d6a980-a343-548e-a6ea-1d62b119f2f4"
version = "3.15.0"

[[ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "024fe24d83e4a5bf5fc80501a314ce0d1aa35597"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.11.0"

[[Colors]]
deps = ["ColorTypes", "FixedPointNumbers", "Reexport"]
git-tree-sha1 = "417b0ed7b8b838aa6ca0a87aadf1bb9eb111ce40"
uuid = "5ae59095-9a9b-59fe-a467-6f913c188581"
version = "0.12.8"

[[Compat]]
deps = ["Base64", "Dates", "DelimitedFiles", "Distributed", "InteractiveUtils", "LibGit2", "Libdl", "LinearAlgebra", "Markdown", "Mmap", "Pkg", "Printf", "REPL", "Random", "SHA", "Serialization", "SharedArrays", "Sockets", "SparseArrays", "Statistics", "Test", "UUIDs", "Unicode"]
git-tree-sha1 = "dce3e3fea680869eaa0b774b2e8343e9ff442313"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "3.40.0"

[[CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"

[[Compose]]
deps = ["Base64", "Colors", "DataStructures", "Dates", "IterTools", "JSON", "LinearAlgebra", "Measures", "Printf", "Random", "Requires", "Statistics", "UUIDs"]
git-tree-sha1 = "c6461fc7c35a4bb8d00905df7adafcff1fe3a6bc"
uuid = "a81c6b42-2e10-5240-aca2-a61377ecd94b"
version = "0.9.2"

[[Contour]]
deps = ["StaticArrays"]
git-tree-sha1 = "9f02045d934dc030edad45944ea80dbd1f0ebea7"
uuid = "d38c429a-6771-53c6-b99e-75d170b6e991"
version = "0.5.7"

[[CoupledFields]]
deps = ["LinearAlgebra", "Statistics", "StatsBase"]
git-tree-sha1 = "6c9671364c68c1158ac2524ac881536195b7e7bc"
uuid = "7ad07ef1-bdf2-5661-9d2b-286fd4296dac"
version = "0.2.0"

[[Crayons]]
git-tree-sha1 = "3f71217b538d7aaee0b69ab47d9b7724ca8afa0d"
uuid = "a8cc5b0e-0ffa-5ad4-8c14-923d3ee1735f"
version = "4.0.4"

[[DataAPI]]
git-tree-sha1 = "cc70b17275652eb47bc9e5f81635981f13cea5c8"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.9.0"

[[DataFrames]]
deps = ["Compat", "DataAPI", "Future", "InvertedIndices", "IteratorInterfaceExtensions", "LinearAlgebra", "Markdown", "Missings", "PooledArrays", "PrettyTables", "Printf", "REPL", "Reexport", "SortingAlgorithms", "Statistics", "TableTraits", "Tables", "Unicode"]
git-tree-sha1 = "d785f42445b63fc86caa08bb9a9351008be9b765"
uuid = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
version = "1.2.2"

[[DataStructures]]
deps = ["Compat", "InteractiveUtils", "OrderedCollections"]
git-tree-sha1 = "7d9d316f04214f7efdbb6398d545446e246eff02"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.18.10"

[[DataValueInterfaces]]
git-tree-sha1 = "bfc1187b79289637fa0ef6d4436ebdfe6905cbd6"
uuid = "e2d170a0-9d28-54be-80f0-106bbe20a464"
version = "1.0.0"

[[Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[DelimitedFiles]]
deps = ["Mmap"]
uuid = "8bb1440f-4735-579b-a4ab-409b98df4dab"

[[DensityInterface]]
deps = ["InverseFunctions", "Test"]
git-tree-sha1 = "794daf62dce7df839b8ed446fc59c68db4b5182f"
uuid = "b429d917-457f-4dbc-8f4c-0cc954292b1d"
version = "0.3.3"

[[Distances]]
deps = ["LinearAlgebra", "Statistics", "StatsAPI"]
git-tree-sha1 = "837c83e5574582e07662bbbba733964ff7c26b9d"
uuid = "b4f34e82-e78d-54a5-968a-f98e89d6e8f7"
version = "0.10.6"

[[Distributed]]
deps = ["Random", "Serialization", "Sockets"]
uuid = "8ba89e20-285c-5b6f-9357-94700520ee1b"

[[Distributions]]
deps = ["ChainRulesCore", "DensityInterface", "FillArrays", "LinearAlgebra", "PDMats", "Printf", "QuadGK", "Random", "SparseArrays", "SpecialFunctions", "Statistics", "StatsBase", "StatsFuns", "Test"]
git-tree-sha1 = "cce8159f0fee1281335a04bbf876572e46c921ba"
uuid = "31c24e10-a181-5473-b8eb-7969acd0382f"
version = "0.25.29"

[[DocStringExtensions]]
deps = ["LibGit2"]
git-tree-sha1 = "b19534d1895d702889b219c382a6e18010797f0b"
uuid = "ffbed154-4ef7-542d-bbb7-c09d3a79fcae"
version = "0.8.6"

[[Downloads]]
deps = ["ArgTools", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"

[[FFTW]]
deps = ["AbstractFFTs", "FFTW_jll", "LinearAlgebra", "MKL_jll", "Preferences", "Reexport"]
git-tree-sha1 = "463cb335fa22c4ebacfd1faba5fde14edb80d96c"
uuid = "7a1cc6ca-52ef-59f5-83cd-3a7055c09341"
version = "1.4.5"

[[FFTW_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "c6033cc3892d0ef5bb9cd29b7f2f0331ea5184ea"
uuid = "f5851436-0d7a-5f13-b9de-f02708fd171a"
version = "3.3.10+0"

[[FillArrays]]
deps = ["LinearAlgebra", "Random", "SparseArrays", "Statistics"]
git-tree-sha1 = "8756f9935b7ccc9064c6eef0bff0ad643df733a3"
uuid = "1a297f60-69ca-5386-bcde-b61e274b549b"
version = "0.12.7"

[[FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "335bfdceacc84c5cdf16aadc768aa5ddfc5383cc"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.4"

[[Formatting]]
deps = ["Printf"]
git-tree-sha1 = "8339d61043228fdd3eb658d86c926cb282ae72a8"
uuid = "59287772-0a20-5a39-b81b-1366585eb4c0"
version = "0.4.2"

[[Future]]
deps = ["Random"]
uuid = "9fa8497b-333b-5362-9e8d-4d0656e87820"

[[Gadfly]]
deps = ["Base64", "CategoricalArrays", "Colors", "Compose", "Contour", "CoupledFields", "DataAPI", "DataStructures", "Dates", "Distributions", "DocStringExtensions", "Hexagons", "IndirectArrays", "IterTools", "JSON", "Juno", "KernelDensity", "LinearAlgebra", "Loess", "Measures", "Printf", "REPL", "Random", "Requires", "Showoff", "Statistics"]
git-tree-sha1 = "13b402ae74c0558a83c02daa2f3314ddb2d515d3"
uuid = "c91e804a-d5a3-530f-b6f0-dfbca275c004"
version = "1.3.4"

[[Grisu]]
git-tree-sha1 = "53bb909d1151e57e2484c3d1b53e19552b887fb2"
uuid = "42e2da0e-8278-4e71-bc24-59509adca0fe"
version = "1.0.2"

[[Hexagons]]
deps = ["Test"]
git-tree-sha1 = "de4a6f9e7c4710ced6838ca906f81905f7385fd6"
uuid = "a1b4810d-1bce-5fbd-ac56-80944d57a21f"
version = "0.2.0"

[[Hyperscript]]
deps = ["Test"]
git-tree-sha1 = "8d511d5b81240fc8e6802386302675bdf47737b9"
uuid = "47d2ed2b-36de-50cf-bf87-49c2cf4b8b91"
version = "0.0.4"

[[HypertextLiteral]]
git-tree-sha1 = "2b078b5a615c6c0396c77810d92ee8c6f470d238"
uuid = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
version = "0.9.3"

[[IOCapture]]
deps = ["Logging", "Random"]
git-tree-sha1 = "f7be53659ab06ddc986428d3a9dcc95f6fa6705a"
uuid = "b5f81e59-6552-4d32-b1f0-c071b021bf89"
version = "0.2.2"

[[IndirectArrays]]
git-tree-sha1 = "012e604e1c7458645cb8b436f8fba789a51b257f"
uuid = "9b13fd28-a010-5f03-acff-a1bbcff69959"
version = "1.0.0"

[[IntelOpenMP_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "d979e54b71da82f3a65b62553da4fc3d18c9004c"
uuid = "1d5cc7b8-4909-519e-a0f8-d0f5ad9712d0"
version = "2018.0.3+2"

[[InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[Interpolations]]
deps = ["AxisAlgorithms", "ChainRulesCore", "LinearAlgebra", "OffsetArrays", "Random", "Ratios", "Requires", "SharedArrays", "SparseArrays", "StaticArrays", "WoodburyMatrices"]
git-tree-sha1 = "61aa005707ea2cebf47c8d780da8dc9bc4e0c512"
uuid = "a98d9a8b-a2ab-59e6-89dd-64a1c18fca59"
version = "0.13.4"

[[InverseFunctions]]
deps = ["Test"]
git-tree-sha1 = "a7254c0acd8e62f1ac75ad24d5db43f5f19f3c65"
uuid = "3587e190-3f89-42d0-90ee-14403ec27112"
version = "0.1.2"

[[InvertedIndices]]
git-tree-sha1 = "bee5f1ef5bf65df56bdd2e40447590b272a5471f"
uuid = "41ab1584-1d38-5bbf-9106-f11c6c58b48f"
version = "1.1.0"

[[IrrationalConstants]]
git-tree-sha1 = "7fd44fd4ff43fc60815f8e764c0f352b83c49151"
uuid = "92d709cd-6900-40b7-9082-c6be49f344b6"
version = "0.1.1"

[[IterTools]]
git-tree-sha1 = "05110a2ab1fc5f932622ffea2a003221f4782c18"
uuid = "c8e1da08-722c-5040-9ed9-7db0dc04731e"
version = "1.3.0"

[[IteratorInterfaceExtensions]]
git-tree-sha1 = "a3f24677c21f5bbe9d2a714f95dcd58337fb2856"
uuid = "82899510-4779-5014-852e-03e436cf321d"
version = "1.0.0"

[[JLLWrappers]]
deps = ["Preferences"]
git-tree-sha1 = "642a199af8b68253517b80bd3bfd17eb4e84df6e"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.3.0"

[[JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "8076680b162ada2a031f707ac7b4953e30667a37"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.2"

[[Juno]]
deps = ["Base64", "Logging", "Media", "Profile"]
git-tree-sha1 = "07cb43290a840908a771552911a6274bc6c072c7"
uuid = "e5e0dc1b-0480-54bc-9374-aad01c23163d"
version = "0.8.4"

[[KernelDensity]]
deps = ["Distributions", "DocStringExtensions", "FFTW", "Interpolations", "StatsBase"]
git-tree-sha1 = "591e8dc09ad18386189610acafb970032c519707"
uuid = "5ab0869b-81aa-558d-bb23-cbf5423bbe9b"
version = "0.6.3"

[[LazyArtifacts]]
deps = ["Artifacts", "Pkg"]
uuid = "4af54fe1-eca0-43a8-85a7-787d91b784e3"

[[LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"

[[LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"

[[LibGit2]]
deps = ["Base64", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"

[[Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[LinearAlgebra]]
deps = ["Libdl"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[Loess]]
deps = ["Distances", "LinearAlgebra", "Statistics"]
git-tree-sha1 = "46efcea75c890e5d820e670516dc156689851722"
uuid = "4345ca2d-374a-55d4-8d30-97f9976e7612"
version = "0.5.4"

[[LogExpFunctions]]
deps = ["ChainRulesCore", "ChangesOfVariables", "DocStringExtensions", "InverseFunctions", "IrrationalConstants", "LinearAlgebra"]
git-tree-sha1 = "be9eef9f9d78cecb6f262f3c10da151a6c5ab827"
uuid = "2ab3a3ac-af41-5b50-aa03-7779005ae688"
version = "0.3.5"

[[Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[MKL_jll]]
deps = ["Artifacts", "IntelOpenMP_jll", "JLLWrappers", "LazyArtifacts", "Libdl", "Pkg"]
git-tree-sha1 = "5455aef09b40e5020e1520f551fa3135040d4ed0"
uuid = "856f044c-d86e-5d09-b602-aeab76dc8ba7"
version = "2021.1.1+2"

[[MacroTools]]
deps = ["Markdown", "Random"]
git-tree-sha1 = "3d3e902b31198a27340d0bf00d6ac452866021cf"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.9"

[[Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"

[[Measures]]
git-tree-sha1 = "e498ddeee6f9fdb4551ce855a46f54dbd900245f"
uuid = "442fdcdd-2543-5da2-b0f3-8c86c306513e"
version = "0.3.1"

[[Media]]
deps = ["MacroTools", "Test"]
git-tree-sha1 = "75a54abd10709c01f1b86b84ec225d26e840ed58"
uuid = "e89f7d12-3494-54d1-8411-f7d8b9ae1f27"
version = "0.5.0"

[[Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "bf210ce90b6c9eed32d25dbcae1ebc565df2687f"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.0.2"

[[Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"

[[NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"

[[OffsetArrays]]
deps = ["Adapt"]
git-tree-sha1 = "043017e0bdeff61cfbb7afeb558ab29536bbb5ed"
uuid = "6fe1bfb0-de20-5000-8ca7-80f57d26f881"
version = "1.10.8"

[[OpenLibm_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "05823500-19ac-5b8b-9628-191a04bc5112"

[[OpenSpecFun_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "13652491f6856acfd2db29360e1bbcd4565d04f1"
uuid = "efe28fd5-8261-553b-a9e1-b2916fc3738e"
version = "0.5.5+0"

[[OrderedCollections]]
git-tree-sha1 = "85f8e6578bf1f9ee0d11e7bb1b1456435479d47c"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.4.1"

[[PDMats]]
deps = ["LinearAlgebra", "SparseArrays", "SuiteSparse"]
git-tree-sha1 = "86a37fba91f9fb5bbc5207e9458a5b831dfebb6b"
uuid = "90014a1f-27ba-587c-ab20-58faa44d9150"
version = "0.11.4"

[[Parsers]]
deps = ["Dates"]
git-tree-sha1 = "ae4bbcadb2906ccc085cf52ac286dc1377dceccc"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.1.2"

[[Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"

[[PlutoUI]]
deps = ["AbstractPlutoDingetjes", "Base64", "Dates", "Hyperscript", "HypertextLiteral", "IOCapture", "InteractiveUtils", "JSON", "Logging", "Markdown", "Random", "Reexport", "UUIDs"]
git-tree-sha1 = "e071adf21e165ea0d904b595544a8e514c8bb42c"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.19"

[[PooledArrays]]
deps = ["DataAPI", "Future"]
git-tree-sha1 = "a193d6ad9c45ada72c14b731a318bedd3c2f00cf"
uuid = "2dfb63ee-cc39-5dd5-95bd-886bf059d720"
version = "1.3.0"

[[Preferences]]
deps = ["TOML"]
git-tree-sha1 = "00cfd92944ca9c760982747e9a1d0d5d86ab1e5a"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.2.2"

[[PrettyTables]]
deps = ["Crayons", "Formatting", "Markdown", "Reexport", "Tables"]
git-tree-sha1 = "d940010be611ee9d67064fe559edbb305f8cc0eb"
uuid = "08abe8d2-0d0c-5749-adfa-8a2ac140af0d"
version = "1.2.3"

[[Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[Profile]]
deps = ["Printf"]
uuid = "9abbd945-dff8-562f-b5e8-e1ebf5ef1b79"

[[QuadGK]]
deps = ["DataStructures", "LinearAlgebra"]
git-tree-sha1 = "78aadffb3efd2155af139781b8a8df1ef279ea39"
uuid = "1fd47b50-473d-5c70-9696-f719f8f3bcdc"
version = "2.4.2"

[[REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[Random]]
deps = ["Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[Ratios]]
deps = ["Requires"]
git-tree-sha1 = "01d341f502250e81f6fec0afe662aa861392a3aa"
uuid = "c84ed2f1-dad5-54f0-aa8e-dbefe2724439"
version = "0.4.2"

[[Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "4036a3bd08ac7e968e27c203d45f5fff15020621"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.1.3"

[[Rmath]]
deps = ["Random", "Rmath_jll"]
git-tree-sha1 = "bf3188feca147ce108c76ad82c2792c57abe7b1f"
uuid = "79098fc4-a85e-5d69-aa6a-4863f24498fa"
version = "0.7.0"

[[Rmath_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "68db32dff12bb6127bac73c209881191bf0efbb7"
uuid = "f50d1b31-88e8-58de-be2c-1cc44531875f"
version = "0.3.0+0"

[[SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"

[[Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[SharedArrays]]
deps = ["Distributed", "Mmap", "Random", "Serialization"]
uuid = "1a1011a3-84de-559e-8e89-a11a2f7dc383"

[[Showoff]]
deps = ["Dates", "Grisu"]
git-tree-sha1 = "91eddf657aca81df9ae6ceb20b959ae5653ad1de"
uuid = "992d4aef-0814-514b-bc4d-f2e9a6c4116f"
version = "1.0.3"

[[Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "b3363d7460f7d098ca0912c69b082f75625d7508"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.0.1"

[[SparseArrays]]
deps = ["LinearAlgebra", "Random"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[SpecialFunctions]]
deps = ["ChainRulesCore", "IrrationalConstants", "LogExpFunctions", "OpenLibm_jll", "OpenSpecFun_jll"]
git-tree-sha1 = "f0bccf98e16759818ffc5d97ac3ebf87eb950150"
uuid = "276daf66-3868-5448-9aa4-cd146d93841b"
version = "1.8.1"

[[StaticArrays]]
deps = ["LinearAlgebra", "Random", "Statistics"]
git-tree-sha1 = "3c76dde64d03699e074ac02eb2e8ba8254d428da"
uuid = "90137ffa-7385-5640-81b9-e52037218182"
version = "1.2.13"

[[Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[[StatsAPI]]
git-tree-sha1 = "1958272568dc176a1d881acb797beb909c785510"
uuid = "82ae8749-77ed-4fe6-ae5f-f523153014b0"
version = "1.0.0"

[[StatsBase]]
deps = ["DataAPI", "DataStructures", "LinearAlgebra", "LogExpFunctions", "Missings", "Printf", "Random", "SortingAlgorithms", "SparseArrays", "Statistics", "StatsAPI"]
git-tree-sha1 = "eb35dcc66558b2dda84079b9a1be17557d32091a"
uuid = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"
version = "0.33.12"

[[StatsFuns]]
deps = ["ChainRulesCore", "InverseFunctions", "IrrationalConstants", "LogExpFunctions", "Reexport", "Rmath", "SpecialFunctions"]
git-tree-sha1 = "385ab64e64e79f0cd7cfcf897169b91ebbb2d6c8"
uuid = "4c63d2b9-4356-54db-8cca-17b64c39e42c"
version = "0.9.13"

[[SuiteSparse]]
deps = ["Libdl", "LinearAlgebra", "Serialization", "SparseArrays"]
uuid = "4607b0f0-06f3-5cda-b6b1-a6196a1729e9"

[[TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"

[[TableTraits]]
deps = ["IteratorInterfaceExtensions"]
git-tree-sha1 = "c06b2f539df1c6efa794486abfb6ed2022561a39"
uuid = "3783bdb8-4a98-5b6b-af9a-565f29a5fe9c"
version = "1.0.1"

[[Tables]]
deps = ["DataAPI", "DataValueInterfaces", "IteratorInterfaceExtensions", "LinearAlgebra", "TableTraits", "Test"]
git-tree-sha1 = "fed34d0e71b91734bf0a7e10eb1bb05296ddbcd0"
uuid = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
version = "1.6.0"

[[Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"

[[Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[WoodburyMatrices]]
deps = ["LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "de67fa59e33ad156a590055375a30b23c40299d3"
uuid = "efce3f68-66dc-5838-9240-27a6d6f5f9b6"
version = "0.5.5"

[[Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"

[[nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"

[[p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
"""

# ╔═╡ Cell order:
# ╠═e45eda6e-3d26-4ade-a729-685ccfa0511e
# ╠═5cf7d1c7-f625-468d-97b0-ee1f78699141
# ╠═bb1c80c3-3f02-4dda-bca4-bd6a0f943a6b
# ╠═c4f88cf6-08f7-404f-8073-0f1b317e698c
# ╠═02249d9d-a1ec-4b72-89cc-b7f52b40031d
# ╠═d02e6ab3-dc40-49c2-a64e-339d767d79a6
# ╠═88986ac1-ee54-43cd-a017-9c36ce453b8a
# ╠═af8f37e4-4f8c-4c7f-b800-eebd5ddd5163
# ╠═d0dd3832-ff07-4e64-9961-d9e4123ac2ea
# ╠═ac02a3ef-a937-4d3b-a0f6-b1f3f1eb0bf3
# ╠═e456cab4-a779-464b-8ef7-c80cdc922789
# ╠═c246a0fc-36e9-46e8-b9ff-12c87d25e022
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
