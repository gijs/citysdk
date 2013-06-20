##GET Interface
              
####General database-wide access to nodes:

<div class="code">
  <table>
    <tr>
      <td>
        <code>GET /nodes</code>
      </td>
      <td class='desc'>
        Returns a list of nodes, as specified through url parameters
        (see below). You will want to limit the selection on
        geography, tag or with layer specifications. Without layer
        spec, only the node information itself is returned.
      </td>
    </tr>
    <tr>
      <td>
        <code>GET /routes</code>
      </td>
      <td class='desc'>
        Returns a list of defined 'routes', see above with 'nodes';
        you'll want to limit the selection.
      </td>
    </tr>
    <tr>
      <td>
        <code>GET /regions</code>
      </td>
      <td class='desc'>
        Returns a list of defined administrative regions, see above
        with 'nodes'; you'll want to limit the selection, usually.
      </td>
    </tr>
    <tr>
      <td>
        <code>GET /ptstops</code>
      </td>
      <td class='desc'>
        Returns a list of defined public transport stops.
      </td>
    </tr>
    <tr>
      <td>
        <code>GET /ptlines</code>
      </td>
      <td class='desc'>
        Returns a list of public transport lines.
      </td>
    </tr>
  </table>
</div>

####URL parameters:
              
There are several ways to specify and narrow down the extend of your request. 
You can specify the geographic area of interest (other than searching 'within' 
an area, as described below), limit your request to data and nodes on specific 
layers, and do searches on name or on specific data in specified layers. 
These options are passed through url parameters. Parameters can be combined
in a single request, where this makes sense.

<div class="code">
  <table>

    <tr>
      <td>
       <code>?per_page=&lt;num&gt;</code>
      </td>
      <td class='desc'>
        Limits the number of returned nodes to <code>&lt;num&gt;</code>. Defaults to 10. The maximum value is capped in the backend, currently to 1000 nodes. Multiple requests may be necessary to get all the data for a request.
      </td>
    </tr>
    
    <tr>
      <td>
       <code>?page=&lt;num&gt;</code>
      </td>
      <td class='desc'>
        Requests page <code>&lt;num&gt;</code>.
      </td>
    </tr>
    
    <tr>
      <td>
       <code>?name=&lt;string&gt;</code>
      </td>
      <td class='desc'>
        Most nodes have a name. This parameter allows you to do a sub-string search on that name. The search is case-insensitive and returns nodes whith the specified <code>&lt;string&gt;</code> anywhere in the name.
      </td>
    </tr>
    <tr>
      <td>
       <code>?layer=&lt;name&gt;</code>
      </td>
      <td class='desc'>
        Limits the request to nodes that have data on any or all of the specified layers. <code>&lt;name&gt;</code> is a single layer or a comma-separated (AND) or pipe-separated (OR) list of layer names. Wildcards can be used after layer name separators. Examples are <code>?layer=admr,cbs</code>; <code>?layer=divv.*|gtfs</code>. Logic cannot be mixed, it is either all ANDs or all ORs.
       </td>
    </tr>

    <tr>
      <td>
       <code>?&lt;layer&gt;::&lt;key&gt;[=&lt;val&gt;]</code>
      </td>
      <td class='desc'>
        Returns nodes with specified key-value pairs on specified layers. When <code>=&lt;val&gt;</code> is ommitted, returns nodes with any value present for that key. For example: <code>?osm::tourism=museum</code> returns all nodes with museums on the osm layer, where <code>?osm::tourism</code> returns any osm node with the tag 'tourism'. You can specify multiple key-value pair filters in a single <code>GET</code> request. By default, only nodes are returned which satisfy <strong>all</strong> specified key-value pair filters (AND), but you can change this behaviour by setting URL parameter <code>?data_op=or</code>. Then, all nodes are returned which satisfy <strong>any</strong> of the specified filters. For example, <code>?osm::tourism=museum|zoo&osm::amenity=theatre&data_op=or</code> will return all OSM nodes that are either a museum, a zoo or a theatre.
      </td>
    </tr>

    <tr>
      <td>
       <code>?lat=&lt;num&gt;&amp;lon=&lt;num&gt;<br/>[&amp;radius=&lt;num&gt;]</code>
      </td>
      <td class='desc'>
        This returns nodes within the specified radius (in meters) around lat/lon. Without the radius parameter the request returns the <code>&lt;per_page&gt;</code> geographically closest matches to lat/lon.
      </td>
    </tr>

    <tr>
      <td>
       <code>?bbox=[&lt;t&gt;,&lt;l&gt;,&lt;b&gt;,&lt;r&gt;]</code>
      </td>
      <td class='desc'>
        Match nodes within the given bounding box. Order of the coordinates is top, left, bottom, right.
      </td>
    </tr>

    <tr>
      <td>
       <code>?geom</code>
      </td>
      <td class='desc'>
        Returns the geometry values of the nodes. No parameter value. When not present the geometry is not returned; this can save considerable bandwidth when node geometries are not needed.
      </td>
    </tr>
    <tr>
      <td>
       <code>?count</code>
      </td>
      <td class='desc'>
        Returns the total of matched nodes in the results. Default is off, as counting can have a considerable impact on performance.
      </td>
    </tr>
  </table>
</div>

The following URL parameters are used to filter routes by the nodes they consist of:

<div class="code">
  <table>

    <tr>
      <td>
       <code>?starts_in=&lt;cdk_id&gt;</code>
      </td>
      <td class='desc'>
        Returns routes starting in a specific node. 
      </td>
    </tr>
    <tr>
      <td>
       <code>?ends_in=&lt;cdk_id&gt;</code>
      </td>
      <td class='desc'>
        Returns routes ending in a specific node. 
      </td>
    </tr>
    <tr>
      <td>
       <code>?contains=&lt;cdk_id&gt;<br />[,&lt;cdk_id&gt;]*</code>
      </td>
      <td class='desc'>
        Returns routes containing a specific set of nodes, in the correct order. The    
        <code>contains</code> parameter takes at least one <code>cdk_id</code>, but you can 
        also specify more nodes in a comma-separated list.
      </td>
    </tr>
  </table>
</div>
                        
####Access to elements within a geographic boundary

Apart from limiting your selection to bounding box or circle radius
parameters in the url (see below), more ususally you'll want to limit
the selection to a particular (administrative) region. The node your are
specifying as a boundary can be any node, really, but will only make
sense in the case of a node with definite area.

<div class="code">
  <table>
    <tr>
      <td>
        <code>GET /&lt;cdk_id&gt;/nodes</code>
      </td>
      <td class='desc'>
        All nodes geographically intersecting with node <code>&lt;cdk_id&gt;</code>.
      </td>
    </tr>
    <tr>
      <td>
        <code>GET /&lt;cdk_id&gt;/routes</code>
      </td>
      <td class='desc'>
        All routes.
      </td>
    </tr>
    <tr>
      <td>
        <code>GET /&lt;cdk_id&gt;/regions</code>
      </td>
      <td class='desc'>
        All regions.
      </td>
    </tr>
    <tr>
      <td>
        <code>GET /&lt;cdk_id&gt;/ptstops</code>
      </td>
      <td class='desc'>
        All public transport stops.
      </td>
    </tr>
    <tr>
      <td>
        <code>GET /&lt;cdk_id&gt;/ptlines</code>
      </td>
      <td class='desc'>
        All public transport lines.
      </td>
    </tr>
  </table>
</div>

####Interface to individual nodes:

<div class="code">
  <table>
    <tr>
      <td>
        <code>GET /&lt;cdk_id&gt;</code>
      </td>
      <td class='desc'>
        Returns data of the node specified. Useful in combination with <code>layer</code> url parameter to return the node together with data on specified layers. Otherwise, only the node's <code>cdk_id</code>, layer, name and, optionally, geometry is returned.
      </td>
    </tr>
    <tr>
      <td>
       <code>GET /&lt;cdk_id&gt;/&lt;layer&gt;</code>
      </td>
      <td class='desc'>
        Shortcut to access node data on a specific layer. Differs from the <code>layer</code> url parameter
        in that this only returns the node data, not the node itself.
      </td>
    </tr>
    <tr>
      <td>
        <code>GET /&lt;cdk_id&gt;/&lt;layer&gt;<br/>/&lt;key&gt;</code>
      </td>
      <td class='desc'>
        Access specific piece of data on a specific layer, see examples.
      </td>
    </tr>
  </table>
</div>
<h4>Layers:</h4>
<div class="code">
  <table>
    <tr>
      <td>
        <code>GET /layers</code>
      </td>
      <td class='desc'>
        Returns a list of the layers currently defined; a general
        Overview of data available in the endpoint.
        Layers can be searched for by name and by category:
        <code>GET /layers?name=divv.*</code> or <code>GET /layers?category=mobility</code>
      </td>
    </tr>
    <tr>
      <td>
        <code>GET /layer/&lt;name&gt;</code>
      </td>
      <td class='desc'>
          Returns information on the specified layer.
      </td>
    </tr>
  </table>
</div>

####Going deeper:
              
Information on nodes can be static, or dynamic. Also, some information is
not stored as such, but can be derived from the data that is. To provide an
interface to these kinds of data, some types of nodes can be queried through
the <b>select</b> command. The general form of this command is
`/<cdk_id>/select/<command>` Currently the following commands are defined:

On nodes:

<div class="code">
  <table>
    <tr>
      <td class='select1'>
        <code>GET /&lt;cdk_id&gt;/select/regions</code>
      </td> 
      <td class='select2'>
        will list the administrative region hierarchy starting at this node.
      </td>
    </tr>
    <tr>
      <td class='select1'>
        <code>GET /&lt;cdk_id&gt;/select/routes</code>
      </td>
      <td class='select2'> will list routes containing this node.</td>
    </tr>
    <tr>
      <td class='select1'>
        <code>GET /&lt;cdk_id&gt;/select/routes_start</code> 
      </td>
      <td class='select2'>
        will list routes starting in this node.
      </td>
    </tr>
    <tr>
      <td class='select1'>
        <code>GET /&lt;cdk_id&gt;/select/routes_end</code>
      </td>
      <td class='select2'>
        will list routes ending in this node.
      </td>
    </tr>
  </table>
</div>

On routes:

<div class="code">
  <table>
    <tr>
      <td class='select1'>
        <code>GET /&lt;cdk_id&gt;/select/nodes</code>
      </td>
      <td class='select2'>
        will list the nodes that make up a route.
      </td>
    </tr>
    <tr>
      <td class='select1'>
        <code>GET /&lt;cdk_id&gt;/select/routes</code>
      </td>
      <td class='select2'>
        will list the routes which nodes intersect with the nodes of route with <code>/&lt;cdk_id&gt;</code>.
      </td>
    </tr>
    <tr>
      <td class='select1'>
        <code>GET /&lt;cdk_id&gt;/select/start_end</code>
      </td>
      <td class='select2'>
         will list the start and end node of a route.
      </td>
    </tr>
  </table>
</div>          
        
On ptstops:

<div class="code">
  <table>
    <tr>
      <td class='select1'>
        <code>GET /&lt;cdk_id&gt;/select/ptlines</code>
      </td>
      <td class='select2'>
        will list the public
                transport lines that frequent a stop
      </td>
    </tr>
    <tr>
      <td class='select1'>
        <code>GET /&lt;cdk_id&gt;/select/schedule</code>
      </td>
      <td class='select2'>
        will list the schedule
                for the coming week for all lines that stop at this stop.
      </td>
    </tr>
    <tr>
      <td class='select1'>
        <code>GET /&lt;cdk_id&gt;/select/now</code>
      </td>
      <td class='select2'>
        will, for eacht line at this
        stop, give you the (real-time) departure times for the coming hour.
      </td>
    </tr>
  </table>
</div>          
        
On ptlines:

<div class="code">
  <table>
    <tr>
      <td class='select1'>
        <code>GET /&lt;cdk_id&gt;/select/ptstops</code>
      </td>
      <td class='select2'>
        will list the public transport stops that make up a pt line.
      </td>
    </tr>
    <tr>
      <td class='select1'>
        <code>GET /&lt;cdk_id&gt;/select/schedule</code>
      </td>
      <td class='select2'>
        will list the schedule for today; 
        adding <code>?day=&lt;n&gt;</code> will list schedule for the <code>&lt;n&gt;</code> days from now.
      </td>
    </tr>
  </table>
</div>  