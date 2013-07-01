##PUT/POST/DELETE Interface
              
####Authentication

To use the CitySDK Mobility Write API, you need a valid user account. For now, we only provide write access to a couple of selected organisations and data owners, but this will change soon. In the meantime, if you have data you think CitySDK desperately needs, you can send an email to 
<a href='&#109;&#97;&#105;lto&#58;%63%69%&#55;4&#37;&#55;&#57;sd&#37;6&#66;%&#52;0wa&#97;&#103;&#46;org'>Citysdk Support</a>

All Write API requests require authentication by means of a session key, a random string that provides temporary, secure access to the Write API. To start a session and request a session key, you need to do the following call:

<div class="code">
  <table>
    <tr>
      <td>
        <code>GET /get_session<br />?e=&lt;email&gt;<br />&amp;p=&lt;password&gt;</code>
      </td>
      <td class='desc'>
        Request a session key using a valid <code>&lt;email&gt;</code> and <code>&lt;password&gt;</code> combination.
      </td>
    </tr>
  </table>
</div>

__Important__: the `/get_session` call requires a __HTTPS connection__ for secure transfer of user account details.

The API response will be of the following form, with the session key in the `results` array:

    {
      "status": "success",
      "results": ["session_key"]
    }

All the following API calls on this page expect this session key in the `X-Auth` HTTP header.

Session keys are valid for __one minute__ only, but each request to the Write API will extend the validity with another minute. After one minute of inactivity, your session will time out and you will need to request a new session key to do new Write API requests.</p>

When done, you should release your session by calling `GET /release_session`, again with your current session key in the <code>X-Auth</code> header. If you don't, you will not be able to acquire a new session util the current one has timed out.

<div class="code">
  <table>
    <tr>
      <td>
        <code>GET /release_session</code>
      </td>
      <td class='desc'>
        Release current session.
      </td>
    </tr>
  </table>
</div>
                
A Ruby utility library to illustrate and manage these steps is available <a href="./citysdk_api.rb" target='new'>here</a>.
              
####Adding Data

<div class="code">
  <table>
    <tr>
      <td>
        <code>PUT /&lt;cdk_id&gt;/&lt;layer&gt;</code>
      </td>
      <td class='desc'>
        Add data to layer <code>&lt;layer&gt;</code> of node <code>&lt;cdk_id&gt;</code>.
      </td>
    </tr>
  </table>
</div>

This call expects a JSON body in the following form:

    {
      "modalities": ["rail"],        
      "data" : {
        "naam_lang": "Amsterdam Centraal",
        "code": "ASD"
      }
    }   

The `data` field is a one-dimensional, unnested JSON object (e.g. a list of key-value pairs). 

If data on layer `<layer>` already exists on node `<cdk_id>` the key-value pairs will be merged with the existing data, overwriting duplicate keys with data from the current API call.

If you want to completely replace all node data instead of merging old data with new data, you will have to use the delete data API call first.

You can supply a `modalities` array containing the types of [transport modalities](#modalities) that are valid for the data you are adding.
            
####Deleting Data

<div class="code">
  <table>
    <tr>
      <td>
        <code>DELETE /&lt;cdk_id&gt;/&lt;layer&gt;</code>
      </td>
      <td class='desc'>
        Delete the layer data of layer <code>&lt;layer&gt;</code> of node <code>&lt;cdk_id&gt;</code>.
      </td>
    </tr>
  </table>
</div>

By default, the node is kept when removing data. Afterwards, the `<cdk_id>` and the associated geometry still exist. If you completely want to delete the data as well as the node itself, you can add `?delete_node=true`. This will only delete the node if it is a node that was created by the layer `<layer>`, of course. Also, the node will not be deleted if other layers have added data to this node.

####Bulk  API: writing/updating multiple nodes and node data at once

<div class="code">
  <table>
    <tr>
      <td>
        <code>PUT /nodes/&lt;layer&gt;</code>
      </td>
      <td class='desc'>
        Write and/or update multiple nodes on layer <code>&lt;layer&gt;</code>.
      </td>
    </td>
  </table>
</div>                                   

You can only write data or create nodes in one layer at a time. Of course, you can only 
modify nodes on layers you own. You can create, modify and delete 
layers in the [CitySDK Mobility CMS](http://cms.citysdk.waag.org/).

### Input

The Bulk API expects JSON in the following form:

    {
      "create": {
        "params": {
          "create_type": "create",
          "srid": 4326
        }      
      },
      "nodes": [
        {
          "id": "ASD",
          "name": "Amsterdam Centraal",
          "modalities": ["rail"],
          "geom" : {
             "type": "Point",
              "coordinates" : [
                4.9002776,
                52.378887
              ]
           },
           "data" : {
              "naam_lang": "Amsterdam Centraal",   
              "code": "ASD"
           }
        },
        {
          "cdk_id": "n46419880",
          "modalities": ["rail"],        
          "data" : {
            "naam_lang": "Amsterdam Centraal",   
            "code": "ASD"
          }       
        }
      ]
    }
     

The <code>create</code> object contains parameters, the <code>nodes</code> array contains the nodes you want to create, update or add data to.</p>

#### Create parameters

- `srid`: define the SRID of the GeoJSON geometries for all new nodes to be created.
- `modalities`: defines the node-level modalitites. Really only relevant for route nodes.
- `create_type`: sets the way the Bulk API handles existing and new nodes. Possible values are `update`, `routes` and `create`. Default is `update`. The differences between the create types are explained in the next paragraph.

#### Nodes

The bulk API can add data to existing nodes and create new nodes and add data to those new nodes. Each node in the `nodes` array require a `data` field, a one-dimensional, unnested JSON object, e.g. a list of key-value pairs. For example:
  
    {
      "key1": "value1",
      "key2": "value2",
      "key3": "value3",
    }

Nodes without a `data` field are skipped.

You can supply a `modalities` array containing the types of [transport modalities](modalities.html) that are valid for the node; these are associated with the layer data, not with the node itself (route nodes can have modalities in themselves).

The `create_type` parameter defines three modes of handling nodes in the `nodes` array.

##### Add data to or update existing nodes

    {"create_type": "update"}

This is the default mode, used if you don't specify `create_type` or if you set `"create_type": "update"`. The update mode only only adds data - on the specified layer - to already existing nodes. Each node in the `nodes` array should specify the `cdk_id` of the node the data should be added to. If data on your layer already exist for this node, this data will first be removed. If you want to append data to existing nodes, you can - for now - only do this by using the add data call for each node separately.

You do not need to provide a `geometry` field and nodes without a `cdk_id` field are skipped. The data will be added to existing nodes with an existing geometry.

##### Create routes and add data

    {"create_type": "routes"}

This mode expects a `cdk_ids` field which contains an ordered list of `cdk_id`s through which the new route should be created. You can also supply an identifier and a name for the new route in the `id` and `name` fields. The API will create a new route with a `cdk_id` based on the layer and identifier and will add the key-value data from the `data` object to the new route. The bulk API will return a list of newly created identifier-`cdk_id` combinations which you can use to link your own systems with CitySDK.

If nodes with a `cdk_id` field are encountered instead, the bulk API will handle those nodes the same way as it would in the default `update` mode described above.

Nodes with an `id` field are disgarded.

##### Create new nodes and add data

    {"create_type": "create"}
  
All new nodes you want to create need to have an `id` field. This identifier must be unique for your layer. You can also supply a name for the new node in the `name` field. Furthermore, you *must* supply a valid [GeoJSON](http://www.geojson.org/) geometry in the `geom` field.

The Bulk API will create a new node with the name and geometry you supplied, and will add the key-value data from the `data` object. The API will generate a new `cdk_id` based on the layer and identifier. The bulk API will return a list of newly created `id`-`cdk_id` combinations which you can use to link your own systems with CitySDK.

In this mode, the bulk API will handle nodes with a `cdk_id` or `cdk_ids` field as it would in `update` or `routes` modes.
    
#### Output

Bulk API output looks like this:

    {
      "status": "success", 
      "create": {
        "results": {
          "updated": [],
          "created": [
            {
              "id": "ASD",
              "cdk_id": "<layer>.asd"
            }
          ],
          "totals": [
            "updated": 0,
            "created": 1
          ]
        }            
      }
    }
  
The `create.results.created` object contains a list of `id`-`cdk_id` combinations which you can use to link your own systems with CitySDK.

### Modalities

CitySDK distinguishes the following modes of transport. You can use any combination of these when creating new routes or when adding new data to existing nodes or routes.

| Modality    | Description           
| :---------- |:------------- 
| `tram`      | Tram, Streetcar, Light rail
| `subway`    | Subway, metro      
| `tram`      | Tram, Streetcar, Light rail
| `subway`    | Subway, Metro
| `rail`      | Rail
| `bus`       | Bus
| `ferry`     | Ferry
| `cable_car` | Cable car
| `gondola`   | Gondola, Suspended cable car
| `funicular` | Funicular
| `airplane`  | Airplane
| `foot`      | Foot, walking
| `bicycle`   | Bicycle
| `moped`     | Light motorbike, moped
| `motorbike` | Motorbike
| `car`       | Car
| `truck`     | Truck
| `horse`     | Horse

    