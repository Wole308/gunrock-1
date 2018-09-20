// ----------------------------------------------------------------
// Gunrock -- Fast and Efficient GPU Graph Library
// ----------------------------------------------------------------
// This source code is distributed under the terms of LICENSE.TXT
// in the root directory of this source distribution.
// ----------------------------------------------------------------

/**
 * @fille
 * mf_test.cu
 *
 * @brief Test related functions for Max Flow algorithm.
 */

//#define debug_aml(a) std::cerr << __FILE__ << ":" << __LINE__ << " " << \
    a << "\n";

#define debug_aml(a) std::cout << __FILE__ << ":" << __LINE__ << " " << \
    a << "\n";


#pragma once

#ifdef BOOST_FOUND
    // Boost includes for CPU Push Relabel Max Flow reference algorithms
    #include <boost/config.hpp>
    #include <iostream>
    #include <string>
    #include <boost/graph/push_relabel_max_flow.hpp>
    #include <boost/graph/adjacency_list.hpp>
    #include <boost/graph/read_dimacs.hpp>
#endif

namespace gunrock {
namespace app {
namespace mf {

/*****************************************************************************
 * Housekeeping Routines
 ****************************************************************************/

/**
 * @brief Displays the MF result
 *
 * @tparam ValueT     Type of capacity/flow/excess
 * @tparam VertxeT    Type of vertex 
 * 
 * @param[in] h_flow  Flow calculated on edges 
 * @param[in] source  Index of source vertex
 * @param[in] nodes   Number of nodes
 */
template<typename ValueT, typename VertexT>
void DisplaySolution(ValueT** h_flow, VertexT source, VertexT nodes)
{
    ValueT flow_outcoming_source = 0;
    for (VertexT v = 0; v < nodes; ++v)
    {
	ValueT flow_source_v = h_flow[source][v];
	if (util::isValid(flow_source_v))
	    flow_outcoming_source += flow_source_v;
    }

    util::PrintMsg("The maximum amount of flow that is feasible to reach \
	    from source to sink is " + std::to_string(flow_outcoming_source), 
	    true, false);
}
/**
 * @brief For given vertex v, find neighbor which the smallest height.  
 *
 * @tparam ValueT	Type of capacity/flow/excess
 * @tparam VertxeT	Type of vertex
 * 
 * @param[in] v		Index of vertex 
 * @param[in] n		Number of nodes
 * @param[in] height	Function of height on nodes 
 * @param[in] capacity	Function of capacity on edges
 * @param[in] flow	Function of flow on edges
 *
 * return Index the lowest neighbor of vertex v
 */
template<typename ValueT, typename VertexT>
VertexT find_lowest(VertexT v, VertexT n, VertexT* height, ValueT** capacity, 
	ValueT** flow){
    VertexT lowest = 2*n + 1;
    VertexT lowest_id = n; //n is init value, n is unreachable by i iterator
    for (VertexT i=0; i<n; ++i){
	if (capacity[v][i] - flow[v][i] > 0){
	    if (lowest_id == n || height[i] < lowest){
		lowest = height[i];
		lowest_id = i;
	    }
	}
    }
    return lowest_id;
}
/**
  * @brief Relabel: increases height of given vertex
  *
  * @tparam ValueT	Type of capacity/flow/excess
  * @tparam VertxeT	Type of vertex
  *
  * @param[in] i	Index of vertex
  * @param[in] n	Number of nodes
  * @param[in] height	Function of height on nodes
  * @param[in] capacity Function of capacity on edges
  * @param[in] flow	Function of flow on edges
  *
  * return True if something changed, false otherwise
  */
template<typename ValueT, typename VertexT>
bool relabel(VertexT i, VertexT n, VertexT* height, ValueT* capacity,
	ValueT* flow, VertexT source, VertexT sink){
    VertexT lowest_neighbour = find_lowest(i, n, height, capacity, flow);
    // n is unreachable value, it means that there is no valid neighbour
    if (lowest_neighbour != n && height[lowest_neighbour] >= height[i]){
	height[i] = height[lowest_neighbour] + 1;
	return true;
    }
    return false;
}
/**
  * @brief Push: transfers flow from given vertex to neighbors in residual 
  *	   network which are lower than it.
  *
  * @tparam ValueT	Type of capacity/flow/excess
  * @tparam VertxeT	Type of vertex
  *
  * @param[in] i	Index of vertex
  * @param[in] n	Number of nodes
  * @param[in] excess	Function of excess on nodes
  * @param[in] height	Function of height on nodes
  * @param[in] capacity Function of capacity on edges
  * @param[in] flow	Function of flow on edges
  *
  * return True if something changed, false otherwise
  */
template<typename ValueT, typename VertexT>
bool push(VertexT i, VertexT n, ValueT* excess, VertexT* height,
	ValueT** capacity, ValueT** flow, VertexT source, VertexT sink){
    bool update = false;
    if (excess[i] > 0){
	for (int j=0; j<n; ++j){
	    if (capacity[i][j] - flow[i][j] > 0 && height[j] < height[i]){
		ValueT move = std::min(capacity[i][j]-flow[i][j], excess[i]);
		if (move == 0)
		    continue;
		excess[i] -= move;
		excess[j] += move;
		flow[i][j] += move;
		flow[j][i] -= move;
		update = true;
	    }
	}
    }
    return update;
}
/**
  * @brief Push relabel reference algorithm
  *
  * @tparam ValueT	Type of capacity/flow/excess
  * @tparam VertxeT	Type of vertex
  *
  * @param[in] capacity Function of capacity on edges
  * @param[in] flow	Function of flow on edges
  * @param[in] excess	Function of excess on nodes
  * @param[in] height	Function of height on nodes
  * @param[in] n	Number of nodes
  * @param[in] source	Source vertex
  * @param[in] sink	Sink vertex
  *
  * return Value of computed max flow
  */
template<typename ValueT, typename VertexT>
ValueT max_flow(ValueT** capacity, ValueT** flow, ValueT* excess, 
	VertexT* height, VertexT n, VertexT source, VertexT sink){
    bool update = true;
    bool source_was_visit = false;
    int iter = 0;
    while (update){
	++iter;
	update = false;
	for (VertexT i=0; i<n; ++i){
	    if (i == sink)
		continue;
	    if (i == source and source_was_visit)
		continue;
	    else if (i == source and not source_was_visit){
		source_was_visit = true;
		debug_aml("visiting source in the " << iter << " iteration");
	    }
	    if (excess[i] > 0){
		if (push(i, n, excess, height, capacity, flow, source, sink) ||
			relabel(i, n, height, capacity, flow, source, sink))
		    update = true;
	    }
	}
    }
    return excess[sink];
}

/****************************************************************************
 * MF Testing Routines
 ***************************************************************************/

/**
 * @brief Simple CPU-based reference MF implementations
 *
 * @tparam GraphT   Type of the graph
 * @tparam ValueT   Type of the capacity/flow/excess
 *
 * @param[in]  parameters Running parameters
 * @param[in]  graph      Input graph
 * @param[in]  src        The source vertex
 * @param[in]  sin        The sink vertex
 * @param[out] maxflow	  Value of computed maxflow reached sink
 * @param[out] edges_flow Computed flows on edges
 *
 * \return     double      Time taken for the MF
 */
template <typename VertexT, typename ValueT, typename GraphT>
double CPU_Reference(
	util::Parameters &parameters,
	GraphT &graph,
	VertexT src,
	VertexT sin,
	ValueT &maxflow,
	ValueT **edge_flow)
{

    debug_aml("CPU_Reference start");

#ifdef BOOST_FOUND
    
    debug_aml("boost found");
    using namespace boost;

    // Prepare Boost Datatype and Data structure
    typedef adjacency_list_traits < vecS, vecS, undirectedS > Traits;

    struct boost_vertex{
	std::string name;
    };

    struct boost_edge{
	/*ValueT*/double capacity;
	/*ValueT*/double  residual_capacity;
	Traits::edge_descriptor reverse;
    };
//    typedef adjacency_list < vecS, vecS, undirectedS, 
//	    property < vertex_name_t, std::string >,
//	    property < edge_capacity_t, ValueT,
//	    property < edge_residual_capacity_t, ValueT,
//	    property < edge_reverse_t, Traits::edge_descriptor > > > > 
//    BGraphT;
    
    typedef adjacency_list < vecS, vecS, undirectedS, boost_vertex, 
	    boost_edge> BGraphT;

    BGraphT boost_graph;
/*
    typename property_map < BGraphT, edge_capacity_t >::type 
	capacity = get(edge_capacity, boost_graph);

    typename property_map < BGraphT, edge_reverse_t >::type 
	rev = get(edge_reverse, boost_graph);

    typename property_map < BGraphT, edge_residual_capacity_t >::type 
	residual_capacity = get(edge_residual_capacity, boost_graph);
*/
    std::vector<Traits::vertex_descriptor> verts;
    for (VertexT v = 0; v < graph.nodes; ++v)
	verts.push_back(add_vertex(boost_graph));
    
    Traits::vertex_descriptor source = verts[src];
    Traits::vertex_descriptor sink = verts[sin];
    debug_aml("src = " << src << ", sin = " << sin);

    for (VertexT e = 0; e < graph.edges; ++e){
	VertexT x = graph.edge_pairs[e].x;
	VertexT y = graph.edge_pairs[e].y;
	ValueT cap = graph.edge_values[e];
	Traits::edge_descriptor e1, e2;
	bool in1, in2;
	tie(e1, in1) = add_edge(verts[x], verts[y], boost_graph);
	tie(e2, in2) = add_edge(verts[y], verts[x], boost_graph);
	boost_graph[e1].reverse = e2;
	boost_graph[e2].reverse = e1;
	boost_graph[e1].capacity = cap;
	boost_graph[e2].capacity = 0;
	boost_graph[e1].residual_capacity = 0;
	boost_graph[e2].residual_capacity = cap;
	if (x == src || y == src || x == sin || y == sin)
	    debug_aml("(" << x << ", " << y << "): " << cap);

	if (!in1 || !in2){
	    std::cerr << __FILE__ << ":" << __LINE__ << std::endl;
	    return -1;
	}
	/*capacity[e1] = cap;
	capacity[e2] = 0;
	rev[e1] = e2;
	rev[e2] = e1;*/
    }

    
    //
    // Perform Boost reference
    //

    util::CpuTimer cpu_timer;
    cpu_timer.Start();

    maxflow = push_relabel_max_flow(boost_graph, source, sink, 
	    boost::get(&boost_edge::capacity, boost_graph),
	    boost::get(&boost_edge::residual_capacity, boost_graph),
	    boost::get(&boost_edge::reverse, boost_graph),
	    boost::get(boost::vertex_index, boost_graph)
	    );

    cpu_timer.Stop();
    double elapsed = cpu_timer.ElapsedMillis();
    
    util::PrintMsg("CPU PushRelabel finished in " + std::to_string(elapsed) +
	    " msec. " + "Max flow is equal " + std::to_string(maxflow), true);

    //
    // Extracting results on CPU
    //
/*
    typename graph_traits<BGraphT>::vertex_iterator u_it, u_end;
    typename graph_traits<BGraphT>::out_edge_iterator e_it, e_end;
    for (tie(u_it, u_end) = vertices(boost_graph); u_it != u_end; ++u_it){
	for (tie(e_it, e_end) = out_edges(*u_it, boost_graph); e_it != e_end; 
		++e_it){
	if (capacity[*e_it] > 0){
	    ValueT e_f = capacity[*e_it] - residual_capacity[*e_it];
	    VertexT t = target(*e_it, boost_graph);
	    util::PrintMsg("flow on edge " + std::to_string(*u_it) + "-" +
		    std::to_string(t) + " is " + std::to_string(e_f));
	    edge_flow[*u_it][t] = e_f;
	}
    }
    }*/

    return elapsed;

#else

    debug_aml("no boost");

    debug_aml("graph nodes " << graph.nodes << ", edges " << graph.edges <<
	    " source vertex " << src << " sink vertex " << sin);

    typedef typename GraphT::CsrT CsrT;

    ValueT* capacity  = (ValueT*)malloc(sizeof(ValueT)*2*graph.edges);
    ValueT* flow      = (ValueT*)malloc(sizeof(ValueT)*2*graph.edges);
    VertexT* reverse  = (VertexT*)malloc(sizeof(VertexT)*graph.edges);
    auto flow_from_source_to_neighbours = 0;
    //auto flow_from_neighbours_to_sink = 0;

    //std::map<VertexT, int> frequency_vertex; 
    //for (VertexT x = 0; x < graph.nodes; ++x) frequency_vertex[x] = 0;
    for (VertexT x = 0; x < graph.nodes; ++x)
    {
	SizeT e_start = graph.CsrT::GetNeighborListOffset(x);
	SizeT num_neighbors = graph.CsrT::GetNeighborListLength(x);
	SizeT e_end = e_start + num_neighbors;
	for (SizeT e = e_start; e < e_end; ++e)
	{
	    capacity[e] = graph.CsrT::edge_values[e];
	    if (x == src){
		flow_from_source_to_neighbours += capacity[e];
	    }
	    /*if (y == sin){
		flow_from_neighbours_to_sink += capacity[x][y];
	    }*/
	}
    }
	   
    }
/*    for (VertexT e = 0; e < graph.edges; ++e){
	VertexT x = graph.CooT::edge_pairs[e].x;
	VertexT y = graph.CooT::edge_pairs[e].y;
	frequency_vertex[x]++;
	frequency_vertex[y]++;
	capacity[x][y] = graph.CooT::edge_values[e];
	if (x == src){
	    flow_from_source_to_neighbours += capacity[x][y];
	}
	if (y == sin){
	    flow_from_neighbours_to_sink += capacity[x][y];
	}
    }*/
    
    //For debug:
    /*
    debug_aml("flow from source to neighbours " << 
	    flow_from_source_to_neighbours);
    debug_aml("flow from neighbours to sink " << 
	    flow_from_neighbours_to_sink);
    std::multimap<int, VertexT> most_common_vertex;
    std::transform(frequency_vertex.begin(), frequency_vertex.end(), 
	    std::inserter(most_common_vertex, most_common_vertex.begin()),
	    [](const std::pair<VertexT, int> &p)
	    {
		return std::pair<int, VertexT>(p.second, p.first);
	    });

    for (auto common = most_common_vertex.rbegin();
	    common != most_common_vertex.rend(); ++ common){
	if (common->second == src)
	{
	    debug_aml("frequency of " << common->second << " is " << 
		    common->first << " ---------->>> SOURCE");
	}else
	if (common->second == sin)
	{
	    debug_aml("frequency of " << common->second << " is " << 
		    common->first << " ---------->>> SINK");
	}
    }
    */
    

    ValueT*   excess =  (ValueT*)malloc(sizeof(ValueT)*graph.nodes);
    VertexT*  height = (VertexT*)malloc(sizeof(VertexT)*graph.nodes);
    for (VertexT v = 0; v < graph.nodes; ++v){
	excess[v] = height[v] = 0;
    }
    height[src] = 2 * graph.nodes + 1;
    excess[src] = std::numeric_limits<ValueT>::max();
    
    //
    // Perform simple max flow reference
    //
    debug_aml("perform simple max flow reference");
    debug_aml("source " << src << " sink " << sin);
    debug_aml("source excess " << excess[src] << ", sink " << excess[sin]);
    debug_aml("source height " << height[src] << ", sink " << height[sin]);
    
    util::CpuTimer cpu_timer;
    cpu_timer.Start();
    maxflow = max_flow(capacity, flow, excess, height, graph.nodes, src, 
	    sin);
    cpu_timer.Stop();
    double elapsed = cpu_timer.ElapsedMillis();

    util::PrintMsg("CPU PushRelabel finished in " + std::to_string(elapsed) +
	    " msec. " + "Max flow is equal " + std::to_string(maxflow), 
	    true);

    //
    // Extracting results on CPU
    //

    std::swap(flow, edge_flow);

    return elapsed;

#endif
}

/**
 * @brief Validation of MF results
 *
 * @tparam     GraphT	      Type of the graph
 * @tparam     ValueT	      Type of the distances
 *
 * @param[in]  parameters     Excution parameters
 * @param[in]  graph	      Input graph
 * @param[in]  source	      The source vertex
 * @param[in]  sink           The sink vertex
 * @param[in]  h_flow	      Computed flow on edges 
 * @param[in]  ref_flow	      Reference flow on edges
 * @param[in]  verbose	      Whether to output detail comparsions
 *
 * \return     int  Number of errors
 */
template <typename GraphT, typename ValueT, typename VertexT>
int Validate_Results(
	util::Parameters  &parameters,
        GraphT		  &graph,
    	VertexT		  source,
    	VertexT		  sink,
        ValueT		  *_h_flow,
        ValueT		  **ref_flow = NULL,
	bool		  verbose = true)
{
    typedef typename GraphT::CooT    CooT;

    int num_errors = 0;
    bool quiet = parameters.Get<bool>("quiet");

    // Create full adjacency matrix corresponding to h_flow
    ValueT** h_flow = (ValueT**)malloc(sizeof(ValueT*)*graph.nodes);
    for (VertexT v = 0; v < graph.nodes; ++v)
    {
	h_flow[v] = (ValueT*)malloc(sizeof(ValueT)*graph.nodes);
	for (VertexT u =0; u < graph.nodes; ++u)
	{
	    h_flow[v][u] = 0;
	}
    }
    for (VertexT v = 0; v < graph.nodes; ++v)
    {
	SizeT e_start = graph.CsrT::GetNeighborListOffset(v);
	SizeT num_neighbors = graph.CsrT::GetNeighborListLength(v);
	SizeT e_end = e_start + num_neighbors;
	for (SizeT e = e_start; e < e_end; ++e)
	{
	    VertexT u = graph.CsrT::GetEdgeDest(e);
	    h_flow[v][u] = _h_flow[e];
	}
	/*VertexT x = graph.CooT::edge_pairs[e].x;
	VertexT y = graph.CooT::edge_pairs[e].y;
	h_flow[x][y] = _h_flow[e];*/
    }

    // Verify the result
    if (ref_flow != NULL)
    {
	for (VertexT v = 0; v < graph.nodes; ++v)
	{
	    for (VertexT u = 0; u < graph.nodes; ++u)
	    {
		if (!util::isValid(ref_flow[v][u])){
		    ref_flow[v][u] = 0;
		}
	    }
	}

	util::PrintMsg("Flow Validity: ", !quiet, false);

	VertexT errors_num = 0;
	for (VertexT v = 0; v < graph.nodes; ++v){
	    errors_num += util::CompareResults(
		h_flow[v], ref_flow[v], graph.nodes, true, quiet);
	}
	if (errors_num > 0)
	{
	    util::PrintMsg(std::to_string(errors_num) + " errors occurred.", 
		    !quiet);
	    num_errors += errors_num;
	}
    }
    else if (ref_flow == NULL)
    {
	util::PrintMsg("Flow Validity: ", !quiet, false);
	VertexT errors_num = 0;
	for (VertexT v = 0; v < graph.nodes; ++v)
	{
	    if (v == source || v == sink)
		continue;
	    ValueT flow_incoming_v = 0;
	    ValueT flow_outcoming_v = 0;
	    for (VertexT u = 0; u < graph.nodes; ++u)
	    {
		ValueT flow_uv = h_flow[u][v];
		if (util::isValid(flow_uv))
		    flow_incoming_v += flow_uv;
		ValueT flow_vu = h_flow[v][u];
		if (util::isValid(flow_vu))
		    flow_outcoming_v += flow_vu;
	    }
	    if (flow_incoming_v == flow_outcoming_v)
		continue;
	    errors_num ++;
	    if (errors_num > 1)
		continue;
	    util::PrintMsg("FAIL: v[" + std::to_string(v) + "]: " +
		    " incoming flow != outcoming flow: " + 
		    std::to_string(flow_incoming_v) + " != " +
		    std::to_string(flow_outcoming_v), !quiet);
	}
	if (errors_num > 0)
	{
	    util::PrintMsg(std::to_string(errors_num) + " errors occurred.", 
		    !quiet);
	    num_errors += errors_num;
	} else {
	    util::PrintMsg("PASS", !quiet);
	}
    }

    if (!quiet && verbose)
    {
	// Display Solution
	util::PrintMsg("Max Flow of the GPU result:");
	DisplaySolution(h_flow, source, graph.nodes);
	if (ref_flow != NULL)
	{
	    util::PrintMsg("Max Flow of the CPU results:");
	    DisplaySolution(ref_flow, source, graph.nodes);
	}
	util::PrintMsg("");
    }

    return num_errors;
}

} // namespace mf
} // namespace app
} // namespace gunrock

// Leave this at the end of the file
// Local Variables:
// mode:c++
// c-file-style: "NVIDIA"
// End:

